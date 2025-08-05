const std = @import("std");
const glue = @import("glue");

const GameState = struct {
    frame: u32 = 0,
};

pub export fn initGameMemory(game_memory: *const glue.GameMemory) callconv(.c) void {
    const game_state: *GameState = @alignCast(@ptrCast(game_memory.permanent_storage));
    game_state.* = .{};
}

pub export fn updateAndRender(buffer: ?*const glue.OffscreenBufferBGRA8, game_memory: *const glue.GameMemory) void {
    const game_state: *GameState = @alignCast(@ptrCast(game_memory.permanent_storage));
    if (buffer) |buff| {
        drawRectangle(buff, .{
            .x = 0.5,
            .y = 0.5,
            .width = 0.5,
            .height = 0.5,
        }, .{
            .r = 1.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        });
    }

    game_state.frame += 1;
}

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const PixelSpaceRect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn fromNormalizedRect(rect: Rect, max_width: u32, max_height: u32) PixelSpaceRect {
        const fw = @as(f32, @floatFromInt(max_width));
        const fh = @as(f32, @floatFromInt(max_height));

        return .{
            .x = @intFromFloat(@floor(rect.x * fw)),
            .y = @intFromFloat(@floor(rect.y * fh)),
            .width = @intFromFloat(@ceil(rect.width * fw)),
            .height = @intFromFloat(@ceil(rect.height * fh)),
        };
    }

    pub fn clampToBounds(self: PixelSpaceRect, max_width: u32, max_height: u32) PixelSpaceRect {
        return .{
            .x = @max(0, @min(self.x, @as(i32, @intCast(max_width)))),
            .y = @max(0, @min(self.y, @as(i32, @intCast(max_height)))),
            .width = @max(0, @min(@as(i32, @intCast(self.width)), @as(i32, @intCast(max_width)) - self.x)),
            .height = @max(0, @min(@as(i32, @intCast(self.height)), @as(i32, @intCast(max_height)) - self.y)),
        };
    }
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn toBGRA8(self: Color) u32 {
        const r = @as(u32, @intFromFloat(@min(self.r * 255.0, 255.0)));
        const g = @as(u32, @intFromFloat(@min(self.g * 255.0, 255.0)));
        const b = @as(u32, @intFromFloat(@min(self.b * 255.0, 255.0)));
        const a = @as(u32, @intFromFloat(@min(self.a * 255.0, 255.0)));

        return b | g << 8 | r << 16 | a << 24;
    }
};

pub fn drawRectangle(
    buffer: *const glue.OffscreenBufferBGRA8,
    rect: Rect,
    color: Color,
) void {
    const color_bgra8 = color.toBGRA8();
    // const pixels: []u32 = buffer.memory[0 .. buffer.width * buffer.height];

    const pixel_space_rect = PixelSpaceRect.fromNormalizedRect(
        rect,
        buffer.width,
        buffer.height,
    );

    const shifted_rect = PixelSpaceRect{
        .x = pixel_space_rect.x - @as(i32, @intCast(@divTrunc(pixel_space_rect.width, 2))),
        .y = pixel_space_rect.y - @as(i32, @intCast(@divTrunc(pixel_space_rect.height, 2))),
        .width = pixel_space_rect.width,
        .height = pixel_space_rect.height,
    };

    const clamped_rect = shifted_rect.clampToBounds(buffer.width, buffer.height);

    const max_x = @as(u32, @intCast(clamped_rect.x)) + clamped_rect.width;
    const max_y = @as(u32, @intCast(clamped_rect.y)) + clamped_rect.height;
    const min_x = @as(u32, @intCast(clamped_rect.x));
    const min_y = @as(u32, @intCast(clamped_rect.y));

    var py = min_y;
    while (py < max_y) : (py += 1) {
        const row_start = py * buffer.width + min_x;
        var px: u32 = 0;
        while (px < (max_x - min_x)) : (px += 1) {
            buffer.memory[row_start + px] = color_bgra8;
        }
    }
}
