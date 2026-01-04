const std = @import("std");
const FramebufferPool = @import("FramebufferPool.zig");
const math = @import("math");
const CommandBuffer = @import("CommandBuffer.zig");
const Graphics = @import("../Graphics/Graphics.zig");
const Texture = @import("Texture.zig");

const Command = Graphics.Command;
const Color = math.Color;
const Rect = math.Rect;
const Vec2f = math.Vec2f;
const AABB = math.AABB;
const Transform2D = math.Transform2D;
const Camera = Graphics.Camera;
const Format = Graphics.Format;
const Sprite = Graphics.Sprite;
const ColorSprite = Sprite.ColorSprite;

const View = @import("Renderer.zig").View;

const edge = math.edge;

const log = std.log.scoped(.renderer);
const assert = std.debug.assert;

pub fn drawColorSprite(
    target: Texture,
    view: View,
    sprite: ColorSprite,
    transform: math.Mat3f,
) void {
    // const mvp = transform.mul(view.view_projection);
    const mvp = view.view_projection.mul(transform);
    const quad = sprite.extents.quad(mvp);

    const bounds = AABB{
        .min = .{ .x = -1.0, .y = -1.0 },
        .max = .{ .x = 1.0, .y = 1.0 },
    };

    // TODO move this

    var vertex_buffer: [8]Vec2f = undefined;
    const polygon_vertices = math.Clip.quad2DByAABB(
        quad,
        bounds,
        &vertex_buffer,
    );

    var vertices_copy: [4]Vec2f = undefined;
    @memcpy(&vertices_copy, polygon_vertices[0..4]);

    applyViewport(polygon_vertices, @floatFromInt(target.width), @floatFromInt(target.height));
    // log.info("extensts = {}\ntransform = {any}\nquad = {any}\nmvp_rows = {any}\nvertices = {any}\nvertices after viewport: {any}\n", .{
    //     sprite.extents,
    //     transform.mat.rows,
    //     quad,
    //     mvp.mat.rows,
    //     vertices_copy,
    //     polygon_vertices,
    // });
    var last_corner_index: u8 = 2;
    while (last_corner_index < polygon_vertices.len) : (last_corner_index += 1) {
        const triangle: [3]Vec2f = .{
            polygon_vertices[0],
            polygon_vertices[last_corner_index - 1],
            polygon_vertices[last_corner_index],
        };
        switch (target.memory) {
            inline else => |_, format| {
                const T: type = format.BackingType();
                rasterizeTriangleColor(T, target.raw(T), triangle, sprite.color);
            },
        }
    }
}

fn applyViewport(vertex_positions: []Vec2f, width: f32, height: f32) void {
    const half_vec: Vec2f.Simd = @splat(0.5);
    const wh_vec: Vec2f.Simd = .{ width, height };
    for (vertex_positions) |*vertex_position| {
        vertex_position.* = vec(((simd(vertex_position.*) * half_vec) + half_vec) * wh_vec);
    }
}

fn rasterizeTriangleColor(comptime T: type, target: Texture.Raw(T), vertex_positions: [3]Vec2f, color: Color) void {
    const aabb = AABB.fromPolygon(&vertex_positions);
    const clamp_upper_y: f32 = @floatFromInt(target.height - 1);
    const clamp_upper_x: f32 = @floatFromInt(target.width - 1);

    const max_y = floorClamp(0.0, clamp_upper_y, aabb.max.y);
    const min_y = ceilClamp(0.0, clamp_upper_y, aabb.min.y);

    const max_x = floorClamp(0.0, clamp_upper_x, aabb.max.x);
    const min_x = ceilClamp(0.0, clamp_upper_x, aabb.min.x);

    const pixel_color: T = target.format.pixel(color);

    const a = vertex_positions[0];
    const b = vertex_positions[1];
    const c = vertex_positions[2];

    for (min_y..max_y + 1) |y| {
        @setRuntimeSafety(false);
        for (min_x..max_x + 1) |x| {
            const pixel_center: Vec2f = .{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            };

            const edge_a = edge(a, b, pixel_center);
            const edge_b = edge(b, c, pixel_center);
            const edge_c = edge(c, a, pixel_center);

            if (edge_a <= 0.0 and edge_b <= 0.0 and edge_c <= 0.0) {
                const pixel_index = y * target.width + x;
                target.memory[pixel_index] = pixel_color;
            }
        }
    }
}
fn RasterizeTriangleInfo(comptime format: Format) type {
    return struct {
        a: Vec2f,
        b: Vec2f,
        c: Vec2f,
        memory: []format.BackingType(),
        width: u32,
        min_x: u32,
        max_x: u32,
        min_y: u32,
        max_y: u32,
        color: format.BackingType(),
    };
}

fn rasterizeFromInfo(comptime format: Format, info: RasterizeTriangleInfo(format)) void {
    for (info.min_y..info.max_y + 1) |y| {
        @setRuntimeSafety(false);
        for (info.min_x..info.max_x + 1) |x| {
            const pixel_center: Vec2f = .{
                .x = @as(f32, @floatFromInt(x)) + 0.5,
                .y = @as(f32, @floatFromInt(y)) + 0.5,
            };

            const edge_a = edge(info.a, info.b, pixel_center);
            const edge_b = edge(info.b, info.c, pixel_center);
            const edge_c = edge(info.c, info.a, pixel_center);

            if (edge_a <= 0.0 and edge_b <= 0.0 and edge_c <= 0.0) {
                const pixel_index = y * info.width + x;
                setPixel(format, info.memory, pixel_index, info.color);
            }
        }
    }
}

inline fn setPixel(comptime format: Format, memory: []u8, pixel_index: usize, color: Texture.Pixel.Type(format)) void {
    switch (format) {
        .bgra8_u => {
            const index = pixel_index * 4;
            const pixel: *u32 = std.mem.bytesAsValue(u32, memory[index .. index + 4]);
            pixel.* = color;
        },
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
