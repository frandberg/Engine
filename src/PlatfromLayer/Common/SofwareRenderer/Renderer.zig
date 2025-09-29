const std = @import("std");
const engine = @import("Engine");

const FramebufferPool = @import("FramebufferPool.zig");
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

pub const State = packed struct(u8) {
    is_rendering: bool = false,
    in_use_index_bits: u2 = 0,
    ready_index_bits: u2 = 0,
    _reserved: u3 = 0,
};

framebuffer_pool: FramebufferPool align(8),
command_buffers: [2]CommandBuffer,
cmd_buffer_backing_mem: []Command,

wake_up: std.Thread.Semaphore = .{},

state: Atomic(State) align(8) = Atomic(State).init(.{}),

const max_commands = 1024;
pub fn init(allocator: std.mem.Allocator, fbp_info: FramebufferPool.Info) !Renderer {
    const framebuffer_pool = try FramebufferPool.init(
        allocator,
        fbp_info,
    );
    errdefer framebuffer_pool.deinit(allocator);
    const cmd_buffer_backing_mem = try allocator.alloc(
        CommandBuffer.Command,
        max_commands * max_frames_in_flight,
    );
    errdefer allocator.free(cmd_buffer_backing_mem);

    const command_buffers = [_]CommandBuffer{
        CommandBuffer.init(cmd_buffer_backing_mem[0..max_commands]),
        CommandBuffer.init(cmd_buffer_backing_mem[max_commands..]),
    };

    return .{
        .framebuffer_pool = framebuffer_pool,
        .command_buffers = command_buffers,
        .cmd_buffer_backing_mem = cmd_buffer_backing_mem,
    };
}

pub fn deinit(self: *const Renderer, allocator: std.mem.Allocator) void {
    allocator.free(self.cmd_buffer_backing_mem);
    self.framebuffer_pool.deinit(allocator);
}

pub fn renderLoop(self: *Renderer, is_running: *Atomic(bool)) void {
    while (true) {
        self.wake_up.wait();
        if (is_running.load(.monotonic) == false) {
            break;
        }
        const framebuffer = self.framebuffer_pool.acquireFree() orelse continue;
        defer self.framebuffer_pool.releaseReady(framebuffer);
        framebuffer.clear(0);

        const command_buffer = self.begin() orelse continue;
        defer self.end(command_buffer);

        for (command_buffer.bufferSlice()) |command| {
            executeCommand(command, framebuffer);
        }
    }
    log.info("Render loop exited", .{});
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: *const CommandBuffer) void {
    if (self.state.load(.acquire).is_rendering) {
        std.log.warn("render called while already rendering, ignoring.", .{});
        return;
    }
    self.releaseCommandBufferAndMakeReady(command_buffer);
    self.wake_up.post();
}

pub fn resizeFramebuffers(self: *Renderer) void {
    self.framebuffer_pool.resize();
}

pub fn acquireReadyFramebuffer(self: *const Renderer) ?Framebuffer {
    return self.framebuffer_pool.acquireReady();
}

pub fn releaseFramebuffer(self: *const Renderer, framebuffer: Framebuffer) void {
    self.framebuffer_pool.releaseBuffer(framebuffer);
}

fn begin(self: *Renderer) ?*CommandBuffer {
    var state = self.state.load(.acquire);

    while (true) {
        assertStateValid(state);
        if (state.ready_index_bits == 0) {
            return null;
        }
        const acquire_index_bit = state.ready_index_bits;
        assert(!state.is_rendering);
        assert(state.in_use_index_bits & state.ready_index_bits == 0);
        assert(std.math.isPowerOfTwo(acquire_index_bit));
        if (self.state.cmpxchgStrong(
            state,
            .{
                .is_rendering = true,
                .in_use_index_bits = state.in_use_index_bits | state.ready_index_bits,
                .ready_index_bits = 0,
            },
            .acquire,
            .monotonic,
        )) |new_state| {
            state = new_state;
        } else {
            const index = @ctz(acquire_index_bit);
            return &self.command_buffers[index];
        }
    }
}

fn end(self: *Renderer, command_buffer: *CommandBuffer) void {
    command_buffer.reset();
    var state = self.state.load(.acquire);

    while (true) {
        assertStateValid(state);
        const cmd_buffer_index_bit = getCommandBufferIndexBit(self, command_buffer);
        assert(state.is_rendering);
        assert(state.in_use_index_bits & cmd_buffer_index_bit != 0);
        if (self.state.cmpxchgStrong(
            state,
            .{
                .is_rendering = false,
                .in_use_index_bits = state.in_use_index_bits & ~cmd_buffer_index_bit,
                .ready_index_bits = state.ready_index_bits,
            },
            .release,
            .monotonic,
        )) |new_state| {
            state = new_state;
        } else {
            return;
        }
    }
}

pub fn acquireCommandBuffer(self: *Renderer) ?*CommandBuffer {
    var state = self.state.load(.acquire);

    while (true) {
        assertStateValid(state);

        const avalible_index_bit: u2 = nextFreeIndexBit(state) orelse return null;
        assert(!state.is_rendering);
        assert(state.in_use_index_bits != 0b11); //we never want to acquire a new command buffer if 2 are already in use
        if (self.state.cmpxchgStrong(
            state,
            .{
                .is_rendering = state.is_rendering,
                .in_use_index_bits = state.in_use_index_bits | avalible_index_bit,
                .ready_index_bits = state.ready_index_bits,
            },
            .acquire,
            .monotonic,
        )) |new_state| {
            state = new_state;
        } else {
            switch (avalible_index_bit) {
                0b01 => return &self.command_buffers[0],
                0b10 => return &self.command_buffers[1],
                else => unreachable,
            }
        }
    }
}

pub fn releaseCommandBufferAndMakeReady(self: *Renderer, command_buffer: *const CommandBuffer) void {
    var state = self.state.load(.acquire);

    const cmd_buffer_index_bit = getCommandBufferIndexBit(self, command_buffer);

    while (true) {
        assertStateValid(state);
        assert(state.in_use_index_bits & cmd_buffer_index_bit != 0);
        assert(state.ready_index_bits & cmd_buffer_index_bit == 0);
        if (self.state.cmpxchgStrong(
            state,
            .{
                .is_rendering = state.is_rendering,
                .in_use_index_bits = state.in_use_index_bits & ~cmd_buffer_index_bit,
                .ready_index_bits = cmd_buffer_index_bit,
            },
            .release,
            .monotonic,
        )) |new_state| {
            state = new_state;
        } else {
            return;
        }
    }
}

fn assertStateValid(state: State) void {
    assert(@popCount(state.ready_index_bits) <= 1);
    assert(state._reserved == 0);
}

fn getCommandBufferIndexBit(self: *Renderer, command_buffer: *const CommandBuffer) u2 {
    if (command_buffer == &self.command_buffers[0]) {
        return 0b01;
    } else if (command_buffer == &self.command_buffers[1]) {
        return 0b10;
    } else unreachable;
}

fn nextFreeIndexBit(state: State) ?u2 {
    assert(state.ready_index_bits == 0 or std.math.isPowerOfTwo(state.ready_index_bits));
    const mask: u2 = 0b11;

    const candidates: u2 = (~state.in_use_index_bits) & (~state.ready_index_bits) & mask;

    if (candidates == 0) return null;

    return candidates & ~candidates + 1; //lowest candidate
}
