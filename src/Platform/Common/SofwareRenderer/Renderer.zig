const std = @import("std");
const engine = @import("Engine");

const FramebufferPool = @import("FramebufferPool.zig");
const BufferPoolState = @import("../BufferPoolState.zig").BufferPoolState;
const Framebuffer = FramebufferPool.Framebuffer;
const CommandBuffer = engine.RenderCommandBuffer;
const Command = CommandBuffer.Command;

const executeCommand = @import("CommandExecutor.zig").executeCommand;

const Renderer = @This();
const log = std.log.scoped(.renderer);
const assert = std.debug.assert;
const Atomic = std.atomic.Value;

//NOTE: Never change this!
//The const is just for clarity.
//Our engine should only work on 2 frame max at a time!
//(Mental note): frames in flights and number of offscreen buffers are separate concepts.
//
const max_frames_in_flight: usize = 2;

framebuffer_pool: FramebufferPool align(8),
cmd_buffer_pool: CommandBufferPool,
is_rendering: Atomic(bool) = Atomic(bool).init(false),

wake_up: std.Thread.Semaphore = .{},

const CommandBufferPool = struct {
    backing_mem: []Command,
    buffers: [max_frames_in_flight]CommandBuffer,
    state: BufferPoolState(max_frames_in_flight) = .{},

    const max_commands = 1024;

    fn init(allocator: std.mem.Allocator) !CommandBufferPool {
        const backing_mem = try allocator.alloc(Command, max_commands * max_frames_in_flight);
        var buffers: [max_frames_in_flight]CommandBuffer = undefined;
        for (0..max_frames_in_flight) |i| {
            buffers[i] = .{
                .buffer = backing_mem[i * max_frames_in_flight * max_commands .. (i + 1) * max_frames_in_flight * max_commands],
                .count = 0,
            };
        }
        return .{
            .backing_mem = backing_mem,
            .buffers = buffers,
        };
    }
    fn deinit(self: *CommandBufferPool, allocator: std.mem.Allocator) void {
        allocator.free(self.backing_mem);
    }

    fn acquireAvalible(self: *CommandBufferPool) ?CommandBuffer {
        return if (self.state.acquireAvalible()) |index| self.getBuffer(index) else null;
    }
    fn releaseReady(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
        self.state.releaseReady(self.getBufferIndex(cmd_buffer), false);
    }

    fn acquireReady(self: *CommandBufferPool) ?CommandBuffer {
        return if (self.state.acquireReady()) |index| self.getBuffer(index) else null;
    }

    fn release(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
        self.buffers[self.getBufferIndex(cmd_buffer)].count = 0;
        self.state.release(self.getBufferIndex(cmd_buffer));
    }
    fn getBuffer(self: *const CommandBufferPool, index: usize) CommandBuffer {
        assert(index < max_frames_in_flight);
        return self.buffers[index];
    }

    fn getBufferIndex(self: *const CommandBufferPool, cmd_buffer: CommandBuffer) usize {
        const index = (@intFromPtr(cmd_buffer.buffer.ptr) - @intFromPtr(self.backing_mem.ptr)) / (@sizeOf(Command) * max_frames_in_flight);
        if (index != 0) {
            assert(index == 1);
        }
        assert(index < max_frames_in_flight);
        return index;
    }
};

pub fn init(allocator: std.mem.Allocator, fbp_info: FramebufferPool.Info) !Renderer {
    const framebuffer_pool = try FramebufferPool.init(
        allocator,
        fbp_info,
    );
    errdefer framebuffer_pool.deinit(allocator);
    const cmd_buffer_pool = try CommandBufferPool.init(allocator);
    errdefer cmd_buffer_pool.deinit();

    return .{
        .framebuffer_pool = framebuffer_pool,
        .cmd_buffer_pool = cmd_buffer_pool,
    };
}

pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
    self.cmd_buffer_pool.deinit(allocator);
    self.framebuffer_pool.deinit(allocator);
}

pub fn renderLoop(self: *Renderer, is_running: *Atomic(bool)) void {
    while (true) {
        self.wake_up.wait();
        if (is_running.load(.monotonic) == false) {
            break;
        }
        const framebuffer = self.framebuffer_pool.acquireAvalible() orelse continue;
        defer self.framebuffer_pool.releaseReady(framebuffer);
        framebuffer.clear(0);

        const command_buffer = self.begin() orelse continue;
        defer self.end(command_buffer);

        for (command_buffer.buffer) |command| {
            executeCommand(command, framebuffer);
        }
    }
    log.info("Render loop exited", .{});
}

pub fn acquireCommandBuffer(self: *Renderer) ?CommandBuffer {
    return self.cmd_buffer_pool.acquireAvalible();
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.releaseReady(command_buffer);
    if (self.is_rendering.load(.monotonic)) {
        std.log.warn("render called while already rendering, ignoring.", .{});

        return;
    }
    self.wake_up.post();
}

fn begin(self: *Renderer) ?CommandBuffer {
    if (self.is_rendering.cmpxchgStrong(
        false,
        true,
        .monotonic,
        .monotonic,
    )) |_| {
        return null;
    }
    if (self.cmd_buffer_pool.acquireReady()) |command_buffer| {
        return command_buffer;
    } else {
        self.is_rendering.store(false, .monotonic);
        return null;
    }
}

fn end(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.release(command_buffer);
    if (self.is_rendering.cmpxchgStrong(
        true,
        false,
        .monotonic,
        .monotonic,
    )) |_| {
        @panic("rendering is false when ending render");
    }
}
