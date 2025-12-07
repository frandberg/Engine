const std = @import("std");
const FramebufferPool = @import("FramebufferPool.zig");
const engine = @import("Engine");
const ecs = engine.ecs;
const math = engine.math;
const Color = math.Color;
const CommandBuffer = engine.RenderCommandBuffer;
const Command = CommandBuffer.Command;
const Rectf = math.Rect(f32);
const Rectu = math.Rect(u32);
const Vec2f = math.Vec2f;
const ColorSprite = ecs.ColorSprite;
const AABB = math.AABB;
const Transform2D = math.Transform2D;

const Framebuffer = FramebufferPool.Framebuffer;

fn edge(a: Vec2f, b: Vec2f, p: Vec2f) f32 {
    const ab: Vec2f = vec(simd(b) - simd(a));
    const ap: Vec2f = vec(simd(p) - simd(a));
    return math.signedArea(ab, ap);
}

const log = std.log.scoped(.renderer);

pub fn executeCommand(command: CommandBuffer.Command, framebuffer: FramebufferPool.Framebuffer) void {
    switch (command) {
        .draw_sprite => |data| {
            drawRect(framebuffer, data.sprite, data.transform);
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
    sprite: ColorSprite,
    transform: Transform2D,
) void {
    const pixel_space_transform = normalToPixelSpace(
        transform,
        @floatFromInt(framebuffer.width),
        @floatFromInt(framebuffer.height),
    );
    //std.debug.print("drawing rect\n", .{});

    const quad = sprite.rect.quad(pixel_space_transform);

    const bounds = AABB{
        .min = .{
            .x = 0.0,
            .y = 0.0,
        },
        .max = .{
            .x = @floatFromInt(framebuffer.width),
            .y = @floatFromInt(framebuffer.height),
        },
    };

    var vertex_buffer: [8]Vec2f = undefined;
    std.debug.print("un clippedf vertices: {any}\n", .{quad});
    const polygon_vertices = math.Clip.quad2DByAABB(
        quad,
        bounds,
        &vertex_buffer,
    );
    std.debug.print("clipped polygon vertices: {any}\n", .{polygon_vertices});

    var last_corner_index: u8 = 2;
    while (last_corner_index < polygon_vertices.len) : (last_corner_index += 1) {
        const triangle: [3]Vec2f = .{
            polygon_vertices[0],
            polygon_vertices[last_corner_index - 1],
            polygon_vertices[last_corner_index],
        };
        rasterizeTriangle(framebuffer, triangle, sprite.color);
    }
}

fn rasterizeTriangle(framebuffer: Framebuffer, vertex_positions: [3]Vec2f, color: Color) void {
    const aabb = AABB.fromPolygon(&vertex_positions);
    const clamp_upper_y: f32 = @floatFromInt(framebuffer.height - 1);
    const clamp_upper_x: f32 = @floatFromInt(framebuffer.width - 1);

    const max_y = floorClamp(0.0, clamp_upper_y, aabb.max.y);
    const min_y = ceilClamp(0.0, clamp_upper_y, aabb.min.y);

    const max_x = floorClamp(0.0, clamp_upper_x, aabb.max.x);
    const min_x = ceilClamp(0.0, clamp_upper_x, aabb.min.x);

    const bgra_color = toBGRA(color);

    const a = vertex_positions[0];
    const b = vertex_positions[1];
    const c = vertex_positions[2];

    for (min_y..max_y + 1) |y| {
        for (min_x..max_x + 1) |x| {
            const pixel_center: Vec2f = .{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            };

            const edge_a = edge(a, b, pixel_center);
            const edge_b = edge(b, c, pixel_center);
            const edge_c = edge(c, a, pixel_center);

            if (edge_a <= 0.0 and edge_b <= 0.0 and edge_c <= 0.0) {
                const pixel_index = y * framebuffer.width + x;
                framebuffer.memory[pixel_index] = bgra_color;
            }
        }
    }
}

fn lessThanByY(a: Vec2f, b: Vec2f) bool {
    return a.y < b.y;
}

fn maxY(vertices: [3]Vec2f, lower: f32, upper: f32) u32 {
    const a = floorClamp(lower, upper, vertices[0].y);
    const b = floorClamp(lower, upper, vertices[1].y);
    const c = floorClamp(lower, upper, vertices[2].y);
    return @max(a, @max(b, c));
}
fn minY(vertices: [3]Vec2f, lower: f32, upper: f32) u32 {
    const a = ceilClamp(lower, upper, vertices[0].y);
    const b = ceilClamp(lower, upper, vertices[1].y);
    const c = ceilClamp(lower, upper, vertices[2].y);
    return @min(a, @min(b, c));
}

fn ceilClamp(lower: f32, upper: f32, y: f32) u32 {
    return @intFromFloat(@ceil(std.math.clamp(y, lower, upper)));
}
fn floorClamp(lower: f32, upper: f32, y: f32) u32 {
    return @intFromFloat(@floor(std.math.clamp(y, lower, upper)));
}

const ClippedRectPolygon = struct {
    const max_corners = 8;

    count: u8,
    corners: [max_corners]Vec2f,
};

const simd = math.simd;
const vec = math.vec;
fn normalToPixelSpace(transform: Transform2D, max_width: f32, max_height: f32) Transform2D {
    const half_width = max_width / 2;
    const half_height = max_height / 2;
    const half_size_vec = simd(Vec2f{ .x = half_width, .y = half_height });

    const onc_vec: Vec2f.Simd = @splat(1.0);
    return .{
        .translation = vec((simd(transform.translation) + onc_vec) * half_size_vec),
        .scale = vec(simd(transform.scale) * half_size_vec),
        .rotation = transform.rotation,
    };
}
