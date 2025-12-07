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

wake_up: std.Thread.Semaphore = .{},

const CommandBufferPool = struct {
    backing_mem: []Command,
    counts: [max_frames_in_flight]usize,
    state: BufferPoolState(max_frames_in_flight) = .{},

    const max_commands = 1024;

    fn init(allocator: std.mem.Allocator) !CommandBufferPool {
        const backing_mem = try allocator.alloc(Command, max_commands * max_frames_in_flight);
        return .{
            .backing_mem = backing_mem,
            .counts = .{ 0, 0 },
        };
    }
    fn deinit(self: *CommandBufferPool, allocator: std.mem.Allocator) void {
        allocator.free(self.backing_mem);
    }

    fn acquireAvalible(self: *CommandBufferPool) ?CommandBuffer {
        const index = self.state.acquireAvalible() orelse return null;

        const buffer = self.getBuffer(index);
        return buffer;
    }
    fn releaseReady(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
        const index = self.getBufferIndex(cmd_buffer);
        self.counts[index] = cmd_buffer.count;
        self.state.releaseReady(index, false);
    }

    fn acquireReady(self: *CommandBufferPool) ?CommandBuffer {
        const index = self.state.acquireReady() orelse return null;
        const buffer = self.getBuffer(index);
        return buffer;
    }

    fn release(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
        const index = self.getBufferIndex(cmd_buffer);
        self.counts[index] = 0;
        self.state.release(index);
    }
    fn getBuffer(self: *const CommandBufferPool, index: usize) CommandBuffer {
        assert(index < max_frames_in_flight);
        return .{
            .buffer = self.backing_mem[index * max_commands .. (index + 1) * max_commands],
            .count = self.counts[index],
        };
    }

    pub fn getBufferIndex(self: *const CommandBufferPool, cmd_buffer: CommandBuffer) u2 {
        assert(@intFromPtr(cmd_buffer.buffer.ptr) >= @intFromPtr(self.backing_mem.ptr));
        const offset_bytes = @intFromPtr(cmd_buffer.buffer.ptr) - @intFromPtr(self.backing_mem.ptr);
        const offset_commands = offset_bytes / @sizeOf(Command);
        assert(offset_commands % max_commands == 0);
        const index: usize = offset_commands / max_commands;
        assert(index < max_frames_in_flight);
        return @intCast(index);
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
    while (is_running.load(.seq_cst) == true) {
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

pub fn acquireCommandBuffer(self: *Renderer) ?CommandBuffer {
    return self.cmd_buffer_pool.acquireAvalible();
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.releaseReady(command_buffer);
    self.wake_up.post();
}

const AutoResetEvent = struct {
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    signaled: bool = false,

    pub fn wait(self: *AutoResetEvent) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // reset before waiting
        self.signaled = false;

        while (!self.signaled) {
            self.cond.wait(&self.mutex);
        }
    }

    pub fn post(self: *AutoResetEvent) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.signaled) {
            self.signaled = true;
            self.cond.signal();
        }
    }
};
