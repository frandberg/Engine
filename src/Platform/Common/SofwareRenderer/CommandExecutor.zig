const std = @import("std");
const FramebufferPool = @import("FramebufferPool.zig");
const engine = @import("Engine");
const math = engine.math;
const CommandBuffer = engine.RenderCommandBuffer;
const Command = CommandBuffer.Command;
const Color = CommandBuffer.Color;
const Rectf = CommandBuffer.Rectf;
const Rectu = CommandBuffer.Rectu;

const log = std.log.scoped(.renderer);

pub fn executeCommand(command: CommandBuffer.Command, framebuffer: FramebufferPool.Framebuffer) void {
    switch (command) {
        .draw_rect => |draw_rect| {
            drawRect(framebuffer, draw_rect.rect, draw_rect.color);
        },
        .clear => |color| {
            @memset(framebuffer.memory, toBGRA(color));
        },
    }
}

fn toBGRA(color: Color) u32 {
    return @as(u32, @intFromFloat(@round(color.b * 255.0))) |
        @as(u32, @intFromFloat(@round(color.g * 255.0))) << 8 |
        @as(u32, @intFromFloat(@round(color.r * 255.0))) << 16 |
        @as(u32, @intFromFloat(@round(color.a * 255.0))) << 24;
}

pub fn drawRect(
    framebuffer: FramebufferPool.Framebuffer,
    rect: Rectf,
    color: Color,
) void {
    const shifted_rect = rect.shift(-rect.width * 0.5, -rect.height * 0.5);

    const cliped_rect = shifted_rect.clip(-1.0, -1.0, 1.0, 1.0);

    const pixel_space_rect = normalizedToPixelSpace(
        cliped_rect,
        framebuffer.width,
        framebuffer.height,
    );

    const bgra_color: u32 = toBGRA(color);

    for (0..pixel_space_rect.height) |y| {
        const start_index = pixel_space_rect.pos.y * framebuffer.width + y * framebuffer.width + pixel_space_rect.pos.x;
        const end_index = start_index + pixel_space_rect.width;

        @memset(framebuffer.memory[start_index..end_index], bgra_color);
        std.debug.assert(framebuffer.memory[start_index] == bgra_color);
    }
}

fn normalizedToPixelSpace(
    rect: Rectf,
    max_width: u32,
    max_height: u32,
) Rectu {
    // log.debug("width: {}, height: {}, width / 2 {}, height / 2 = {}")
    const x: u32 = @intFromFloat(@round(((rect.pos.x + 1.0) / 2.0) * @as(f32, @floatFromInt(max_width))));
    const y: u32 = @intFromFloat(@round(((rect.pos.y + 1.0) / 2.0) * @as(f32, @floatFromInt(max_height))));
    const width: u32 = @intFromFloat(@round((rect.width / 2.0) * @as(f32, @floatFromInt(max_width))));
    const height: u32 = @intFromFloat(@round((rect.height / 2.0) * @as(f32, @floatFromInt(max_height))));

    return .{
        .pos = .{
            .x = x,
            .y = y,
        },
        .width = width,
        .height = height,
    };
}
