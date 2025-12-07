const std = @import("std");
const ecs = @import("ecs");

const math = @import("math");
const Color = math.Color;
const ColorSprite = ecs.RendererComponents.ColorSprite;

const CommandBuffer = @This();

const log = std.log.scoped(.command_recorder);

buffer: []Command,
count: usize = 0,

pub const DrawColorSprite = struct {
    sprite: ColorSprite,
    transform: math.Transform2D,
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
