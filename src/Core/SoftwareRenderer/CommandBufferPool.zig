const std = @import("std");
const utils = @import("utils");
const CommandBuffer = @import("CommandBuffer.zig");
const Graphics = @import("../Graphics/Graphics.zig");
const Mailbox = utils.Mailbox;

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Command = Graphics.Command;
const Atomic = std.atomic.Value;
const log = std.log.scoped(.CommandBufferPool);

pub const max_frames_in_flight: usize = 3;

const CommandBufferPool = @This();

const StateIntT: type = std.math.IntFittingRange(0, 1 << max_frames_in_flight);
const max_commands = 1024;

backing_mem: []Command,
counts: [max_frames_in_flight]usize = .{0} ** max_frames_in_flight,
state: Mailbox = .{},

pub fn init(allocator: Allocator) !CommandBufferPool {
    const backing_mem = try allocator.alloc(Command, max_commands * max_frames_in_flight);
    return .{
        .backing_mem = backing_mem,
    };
}
pub fn deinit(self: *CommandBufferPool, allocator: Allocator) void {
    allocator.free(self.backing_mem);
}

pub fn acquire(self: *CommandBufferPool) CommandBuffer {
    const index = self.state.acquire();
    return self.getBuffer(index);
}

pub fn publish(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
    const index = self.getBufferIndex(cmd_buffer);
    self.counts[index] = cmd_buffer.count;
    self.state.publish(index);
}

pub fn consume(self: *CommandBufferPool) ?CommandBuffer {
    const index = self.state.consume();
    if (index) |i| {
        return self.getBuffer(i);
    }
    return null;
}

pub fn release(self: *CommandBufferPool, cmd_buffer: CommandBuffer) void {
    const index = self.getBufferIndex(cmd_buffer);
    self.counts[index] = 0;
    self.state.release();
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
