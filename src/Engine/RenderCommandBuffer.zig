const std = @import("std");

const math = @import("math.zig");

const CommandBuffer = @This();

const log = std.log.scoped(.command_recorder);

buffer: []Command,
count: usize = 0,

pub const Command = union(enum) {
    draw_rect: DrawRect,

    pub const DrawRect = struct {
        rect: math.Rect,
        color: math.Vec4,
    };
};

pub fn init(memory: []Command) CommandBuffer {
    return .{
        .buffer = memory,
    };
}
pub fn deinit(_: *CommandBuffer) void {}

pub fn push(self: *CommandBuffer, command: Command) void {
    self.buffer[self.count] = command;
    self.count += 1;
}

pub fn bufferSlice(self: *const CommandBuffer) []const Command {
    return self.buffer[0..self.count];
}
