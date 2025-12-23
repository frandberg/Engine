const std = @import("std");
const utils = @import("utils");

const math = @import("math");
const Mat3f = math.Mat3f;

pub const FramebufferPool = @import("FramebufferPool.zig");
pub const Framebuffer = FramebufferPool.Framebuffer;

const CommandBuffer = @import("../CommandBuffer.zig");
const CommandBufferPool = @import("../CommandBufferPool.zig");
const Command = CommandBuffer.Command;
const BufferPoolState = utils.BufferPoolState;

const Render = @import("../Render.zig");
const Camera = Render.Camera;
const Frame = Render.Frame;

const max_frames_in_flight = CommandBufferPool.max_frames_in_flight;

const assert = std.debug.assert;
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;

const CmdExecutor = @import("CommandExecutor.zig");
const drawColorSprite = CmdExecutor.drawColorSprite;
const toBGRA = CmdExecutor.toBGRA;

const Renderer = @This();
const log = std.log.scoped(.renderer);

pub const View = struct {
    view_projection: Mat3f,
    viewport: math.Rect,
};

framebuffer_pool: FramebufferPool,
cmd_buffer_pool: CommandBufferPool,
active_view: View,

wake_up: std.Thread.Semaphore = .{},

pub fn init(
    allocator: Allocator,
    fb_width: u32,
    fb_height: u32,
) !Renderer {
    const framebuffer_pool: FramebufferPool = try .init(
        allocator,
        fb_width,
        fb_height,
    );
    errdefer framebuffer_pool.deinit(allocator);

    const cmd_buffer_pool: CommandBufferPool = try .init(allocator);
    errdefer cmd_buffer_pool.deinit(allocator);

    return .{
        .framebuffer_pool = framebuffer_pool,
        .cmd_buffer_pool = cmd_buffer_pool,
        .active_view = undefined,
    };
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    self.framebuffer_pool.deinit(allocator);
    self.cmd_buffer_pool.deinit(allocator);
}

pub fn renderLoop(self: *Renderer, isRunning: *const fn () bool) void {
    while (isRunning()) {
        while (self.cmd_buffer_pool.consume()) |cmd_buffer| {
            const framebuffer = self.framebuffer_pool.acquire() orelse continue;
            for (cmd_buffer.slice()) |command| {
                self.executeCommand(command, framebuffer);
            }
            self.cmd_buffer_pool.release(cmd_buffer);
            self.framebuffer_pool.publish(framebuffer);
        }
        self.wake_up.wait();
    }
    log.info("Render loop exited", .{});
}

pub fn executeCommand(self: *Renderer, command: CommandBuffer.Command, framebuffer: FramebufferPool.Framebuffer) void {
    switch (command) {
        .set_view => |view| {
            self.active_view = View{
                .view_projection = view.camera.viewProjection(-1.0, 1.0, -1.0, 1.0),
                .viewport = view.viewport,
            };
        },
        .draw_color_sprite => |data| {
            drawColorSprite(framebuffer, self.active_view, data.sprite, data.transform);
        },
        .clear => |color| {
            @memset(framebuffer.memory, toBGRA(color));
        },
    }
}

pub fn requestResize(self: *Renderer, new_width: u32, new_height: u32) void {
    self.framebuffer_pool.requestResize(new_width, new_height);
}

pub fn resizeState(self: *const Renderer) FramebufferPool.ResizeState {
    return self.framebuffer_pool.resize_state.load(.monotonic);
}

pub fn setResizeState(self: *Renderer, state: FramebufferPool.ResizeState) void {
    self.framebuffer_pool.resize_state.store(state, .monotonic);
}

pub fn acquireCommandBuffer(self: *Renderer) CommandBuffer {
    return self.cmd_buffer_pool.acquire();
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.publish(command_buffer);
    self.wake_up.post();
}
