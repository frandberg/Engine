const std = @import("std");
const utils = @import("utils");
const CommandBuffer = @import("CommandBuffer.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Command = CommandBuffer.Command;
const BufferPoolState = utils.BufferPoolState;

//NOTE: Never change this!
//The const is just for clarity.
//Our engine should only work on 2 frame max at a time!
//(Mental note): frames in flights and number of offscreen buffers are separate concepts.
const max_frames_in_flight: usize = 2;

const CommandBufferPool = @This();

backing_mem: []Command,
counts: [max_frames_in_flight]usize,
state: BufferPoolState(max_frames_in_flight) = .{},

const max_commands = 1024;

pub fn init(allocator: Allocator) !CommandBufferPool {
    const backing_mem = try allocator.alloc(Command, max_commands * max_frames_in_flight);
    return .{
        .backing_mem = backing_mem,
        .counts = .{ 0, 0 },
    };
}
pub fn deinit(self: *CommandBufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_mem);
}

pub fn acquireAvalible(self: *CommandBufferPool) ?CommandBuffer {
    const index = self.state.acquireAvalible() orelse return null;
    const buffer = self.getBuffer(index);
    return buffer;
}
pub fn releaseReady(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
    const index = self.getBufferIndex(cmd_buffer);
    self.counts[index] = cmd_buffer.count;
    self.state.releaseReady(index, false);
}

pub fn acquireReady(self: *CommandBufferPool) ?CommandBuffer {
    const index = self.state.acquireReady() orelse return null;
    const buffer = self.getBuffer(index);
    return buffer;
}

pub fn release(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
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

fn getBufferIndex(self: *const CommandBufferPool, cmd_buffer: CommandBuffer) u2 {
    assert(@intFromPtr(cmd_buffer.buffer.ptr) >= @intFromPtr(self.backing_mem.ptr));
    const offset_bytes = @intFromPtr(cmd_buffer.buffer.ptr) - @intFromPtr(self.backing_mem.ptr);
    const offset_commands = offset_bytes / @sizeOf(Command);
    assert(offset_commands % max_commands == 0);
    const index: usize = offset_commands / max_commands;
    assert(index < max_frames_in_flight);
    return @intCast(index);
}
