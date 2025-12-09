const std = @import("std");
const Sprite = @import("Sprite.zig");

const math = @import("math");
const Color = math.Color;
const ColorSprite = Sprite.ColorSprite;
const Transform2D = math.Transform2D;

const CommandBuffer = @This();

const log = std.log.scoped(.command_recorder);

buffer: []Command,
count: usize = 0,

pub const DrawColorSprite = struct {
    sprite: ColorSprite,
    transform: Transform2D,
};
pub const Command = union(enum) {
    draw_sprite: DrawColorSprite,
    clear: Color,
};

pub fn init(memory: []Command) CommandBuffer {
    return .{
        .buffer = memory,
    };
}
pub fn deinit(_: *CommandBuffer) void {}

pub fn push(self: *CommandBuffer, command: Command) void {
    if (self.count + 1 == self.buffer.len) {
        log.warn("max render commands reached\n", .{});
        return;
    }
    self.buffer[self.count] = command;
    self.count += 1;
}

pub inline fn slice(self: *const CommandBuffer) []const Command {
    return self.buffer[0..self.count];
}
