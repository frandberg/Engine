const std = @import("std");
const math = @import("math");
const Graphics = @import("../Graphics/Graphics.zig");

const Command = Graphics.Command;
const Sprite = Graphics.Sprite;
const Camera = Graphics.Camera;

const Color = math.Color;
const ColorSprite = Sprite.ColorSprite;
const Transform2D = math.Transform2D;

const CommandBuffer = @This();

const log = std.log.scoped(.command_recorder);

buffer: []Command,
count: usize = 0,

const vtab: Graphics.CommandBuffer.VTab = .{
    .push = push,
};

pub fn init(memory: []Command) CommandBuffer {
    return .{
        .buffer = memory,
    };
}
pub fn deinit(_: *CommandBuffer) void {}

pub fn cmdBuffer(self: *CommandBuffer) Graphics.CommandBuffer {
    return .{
        .ptr = self,
        .vtab = &vtab,
    };
}

pub inline fn slice(self: *const CommandBuffer) []const Command {
    return self.buffer[0..self.count];
}

fn push(ptr: *anyopaque, command: Command) void {
    const self: *CommandBuffer = @ptrCast(@alignCast(ptr));
    if (self.count + 1 == self.buffer.len) {
        log.warn("max render commands reached\n", .{});
        return;
    }
    self.buffer[self.count] = command;
    self.count += 1;
}
