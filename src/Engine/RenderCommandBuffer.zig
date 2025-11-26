const std = @import("std");

const math = @import("math");
const Color = math.Color;
const Sprite = @import("Sprite.zig");

const CommandBuffer = @This();

const log = std.log.scoped(.command_recorder);

buffer: []Command,
count: usize = 0,

pub const Command = union(enum) {
    draw_rect: Sprite,
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

pub fn bufferSlice(self: *const CommandBuffer) []const Command {
    return self.buffer[0..self.count];
}

pub fn Rect(comptime T: type) type {
    return struct {
        const Vec2 = math.Vec2(T);
        pos: Vec2,
        width: T,
        height: T,

        const two: T = @as(T, 2);

        pub inline fn max(self: Rect) Vec2 {
            return .{
                .x = self.pos.x + self.widht / two,
                .y = self.pos.y + self.height / two,
            };
        }

        pub inline fn min(self: Rect) Vec2 {
            return .{
                .x = self.pos.x - self.widht / two,
                .y = self.pos.y - self.height / two,
            };
        }

        pub fn shift(rect: @This(), x: T, y: T) @This() {
            return .{
                .pos = .{ .x = rect.pos.x + x, .y = rect.pos.y + y },
                .width = rect.width,
                .height = rect.height,
            };
        }

        pub fn clip(rect: @This(), min_x: T, min_y: T, max_x: T, max_y: T) @This() {
            const new_x = @max(min_x, rect.pos.x);
            const new_y = @max(min_y, rect.pos.y);
            const new_w = @min(max_x, rect.pos.x + rect.width) - new_x;
            const new_h = @min(max_y, rect.pos.y + rect.height) - new_y;

            return .{
                .pos = .{ .x = new_x, .y = new_y },
                .width = if (new_w > 0.0) new_w else 0.0,
                .height = if (new_h > 0.0) new_h else 0.0,
            };
        }
    };
}

pub const Rectf = Rect(f32);
pub const Rectu = Rect(u32);
