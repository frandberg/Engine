const std = @import("std");
const FramebufferPool = @import("FramebufferPool.zig");
const engine = @import("Engine");
const CommandBuffer = engine.RenderCommandBuffer;
const Command = CommandBuffer.Command;

const log = std.log.scoped(.renderer);

const Rect = engine.math.Rect;
const Vec4 = engine.math.Vec4;

pub fn executeCommand(command: CommandBuffer.Command, framebuffer: FramebufferPool.Framebuffer) void {
    switch (command) {
        .draw_rect => |draw_rect| {
            drawRect(framebuffer, draw_rect.rect, draw_rect.color);
        },
    }
}

pub fn drawRect(
    framebuffer: FramebufferPool.Framebuffer,
    rect: Rect,
    color: Vec4,
) void {
    const shifted_rect = rect.shift(-rect.size[0] * 0.5, -rect.size[1] * 0.5);
    const cliped_rect = shifted_rect.clip(-1.0, -1.0, 1.0, 1.0);

    const pixel_space_rect = PixelSpaceRect.fromNormalizedRect(
        cliped_rect,
        framebuffer.width,
        framebuffer.height,
    );

    const bgra_color: u32 =
        @as(u32, @intFromFloat(@round(color[2] * 255.0))) |
        @as(u32, @intFromFloat(@round(color[1] * 255.0))) << 8 |
        @as(u32, @intFromFloat(@round(color[0] * 255.0))) << 16 |
        @as(u32, @intFromFloat(@round(color[3] * 255.0))) << 24;

    for (0..pixel_space_rect.height) |y| {
        const start_index = pixel_space_rect.y * framebuffer.width + y * framebuffer.width + pixel_space_rect.x;
        const end_index = start_index + pixel_space_rect.width;

        @memset(framebuffer.memory[start_index..end_index], bgra_color);
    }
}

const PixelSpaceRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,

    //normalized here means NDC (-1, 1)
    fn fromNormalizedRect(
        rect: Rect,
        max_width: u32,
        max_height: u32,
    ) PixelSpaceRect {
        // log.debug("width: {}, height: {}, width / 2 {}, height / 2 = {}")
        const x: u32 = @intFromFloat(@round(((rect.pos[0] + 1.0) / 2.0) * @as(f32, @floatFromInt(max_width))));
        const y: u32 = @intFromFloat(@round(((rect.pos[1] + 1.0) / 2.0) * @as(f32, @floatFromInt(max_height))));
        const width: u32 = @intFromFloat(@round((rect.size[0] / 2.0) * @as(f32, @floatFromInt(max_width))));
        const height: u32 = @intFromFloat(@round((rect.size[1] / 2.0) * @as(f32, @floatFromInt(max_height))));

        return .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }
};
