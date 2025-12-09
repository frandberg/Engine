const std = @import("std");
const utils = @import("utils");

pub const FramebufferPool = @import("FramebufferPool.zig");
pub const Framebuffer = FramebufferPool.Framebuffer;

const CommandBuffer = @import("../Render/CommandBuffer.zig");
const CommandBufferPool = @import("../Render/CommandBufferPool.zig");
const Command = CommandBuffer.Command;
const BufferPoolState = utils.BufferPoolState;

const assert = std.debug.assert;
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;

const executeCommand = @import("CommandExecutor.zig").executeCommand;

const Renderer = @This();
const log = std.log.scoped(.renderer);

framebuffer_pool: FramebufferPool,
cmd_buffer_pool: *CommandBufferPool,
is_running: *const Atomic(bool),

wake_up: std.Thread.Semaphore = .{},

pub fn init(allocator: Allocator, cmd_buffer_pool: *CommandBufferPool, is_running: *const Atomic(bool), fb_width: u32, fb_height: u32) !Renderer {
    const framebuffer_pool = try FramebufferPool.init(
        allocator,
        fb_width,
        fb_height,
    );
    errdefer framebuffer_pool.deinit(allocator);

    return .{
        .is_running = is_running,
        .framebuffer_pool = framebuffer_pool,
        .cmd_buffer_pool = cmd_buffer_pool,
    };
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    self.framebuffer_pool.deinit(allocator);
}

pub fn renderLoop(self: *Renderer) void {
    while (self.is_running.load(.seq_cst) == true) {
        while (self.cmd_buffer_pool.acquireReady()) |command_buffer| {
            const framebuffer = self.framebuffer_pool.acquireAvalible() orelse continue;
            defer self.framebuffer_pool.releaseReady(framebuffer);

            for (command_buffer.buffer[0..command_buffer.count]) |command| {
                executeCommand(command, framebuffer);
            }
            self.cmd_buffer_pool.release(command_buffer);
        }
        self.wake_up.wait();
    }
    log.info("Render loop exited", .{});
}

pub fn resizeState(self: *const Renderer) FramebufferPool.ResizeState {
    return self.framebuffer_pool.resize_state.load(.monotonic);
}

pub fn setResizeState(self: *Renderer, state: FramebufferPool.ResizeState) void {
    self.framebuffer_pool.resize_state.store(state, .monotonic);
}

pub fn acquireCommandBuffer(self: *Renderer) ?CommandBuffer {
    return self.cmd_buffer_pool.acquireAvalible();
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.releaseReady(command_buffer);
    self.wake_up.post();
}
