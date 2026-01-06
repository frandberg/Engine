const std = @import("std");
const FramebufferPool = @import("FramebufferPool.zig");
const math = @import("math");
const CommandBuffer = @import("CommandBuffer.zig");
const Graphics = @import("../Graphics/Graphics.zig");
const Texture = @import("Texture.zig");
const Target = @import("Target.zig");
const View = @import("Renderer.zig").View;

const Command = Graphics.Command;
const Color = math.Color;
const Rect = math.Rect;
const Vec2f = math.Vec2f;
const AABB = math.AABB;
const AABBu = math.AABBu;
const Transform2D = math.Transform2D;
const Camera = Graphics.Camera;
const Format = Graphics.Format;
const Sprite = Graphics.Sprite;
const ColorSprite = Sprite.ColorSprite;
const BoundTarget = Target.Bound;
const Vector = math.Vector;

const vec = math.vec;
const simd = math.simd;
const edge = math.edge;

const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const log = std.log.scoped(.renderer);
const assert = std.debug.assert;

pub fn colorSprite(
    target: BoundTarget,
    view: View,
    sprite: ColorSprite,
    transform: math.Mat3f,
) void {
    //const mvp = transform.mul(view.view_projection);
    const mvp = view.view_projection.mul(transform);
    const quad = sprite.extents.quad(mvp);

    // var vertex_buffer: [8]Vec2f = undefined;
    // const polygon_vertices = math.Clip.quad2DByAABB(
    //     quad,
    //     view.viewport,
    //     &vertex_buffer,
    // );
    //
    var vertex_buffer: [@sizeOf(Vec2f) * 8 * 2 * 2]u8 = undefined;
    var fba: FixedBufferAllocator = .init(&vertex_buffer);

    const polygon_vertices = math.Clip.clip(
        fba.allocator(),
        &quad,
        &view.viewport,
    ) catch @panic("failed to clip OOM");

    applyPixelSpaceTransform(
        polygon_vertices,
        target.texture.width,
        target.texture.height,
        target.pixel_origin == .top_left,
    );

    var last_corner_index: u8 = 2;
    var color_index: usize = 0;

    while (last_corner_index < polygon_vertices.len) : (last_corner_index += 1) {
        // const c = if (color_index % 5 == 0) red else if (color_index % 5 == 1) green else if (color_index % 5 == 2) blue else if (color_index % 5 == 3) yellow else orange;
        const c = white;
        const triangle: [3]Vert = .{
            .{ .position = polygon_vertices[0], .varyings = .{ .color = c } },
            .{ .position = polygon_vertices[last_corner_index - 1], .varyings = .{ .color = c } },
            .{ .position = polygon_vertices[last_corner_index], .varyings = .{ .color = c } },
        };
        switch (target.texture.memory) {
            inline else => |_, format| {
                // rasterizeTriangleColor(format, target.texture.raw(format), triangle, red);
                rasterizeTriangle(format, ColorVaryings, target.texture.raw(format), triangle);
            },
        }
        color_index += 1;
    }
}

const Vert = Vertex(ColorVaryings);

const ColorVaryings = struct {
    color: Color,
};

const red = Color{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
const green = Color{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
const blue = Color{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 };
const yellow = Color{ .r = 1.0, .g = 1.0, .b = 0.0, .a = 1.0 };
const orange = Color{ .r = 1.0, .g = 0.5, .b = 0.0, .a = 1.0 };
const white = Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

fn applyPixelSpaceTransform(vertex_positions: []Vec2f, width: u32, height: u32, flip_y: bool) void {
    const f_width: f32 = @floatFromInt(width);
    const f_height: f32 = @floatFromInt(height);
    for (vertex_positions) |*vertex_position| {
        const x = vertex_position.x;
        const y = if (flip_y) -vertex_position.y else vertex_position.y;
        vertex_position.x = ((x + 1.0) * 0.5) * f_width;
        vertex_position.y = ((y + 1.0) * 0.5) * f_height;
    }
}

fn ceilClamp(lower: f32, upper: f32, y: f32) u32 {
    return @intFromFloat(@ceil(std.math.clamp(y, lower, upper)));
}
fn floorClamp(lower: f32, upper: f32, y: f32) u32 {
    return @intFromFloat(@floor(std.math.clamp(y, lower, upper)));
}

pub fn Vertex(comptime Varyings: type) type {
    return struct {
        pub const VaryingsT = Varyings;
        position: Vec2f,
        varyings: Varyings,
    };
}

pub fn rasterizeTriangle(
    comptime format: Format,
    comptime Varyings: type,
    target: Texture.Raw(format),
    vertices: [3]Vertex(Varyings),
) void {
    const vertex_positions = vertexPositions(vertices);

    const area = edge(vertex_positions[0], vertex_positions[1], vertex_positions[2]);
    assert(area < 0.0);
    const inverse_area = 1.0 / area;

    const varyings_array = varyingsArray(Varyings, vertices);

    const aabb = triangleAABB(vertex_positions, target.width, target.height);

    const top_left = topLeftEdges(vertex_positions);

    for (aabb.min.y..aabb.max.y + 1) |y| {
        @setRuntimeSafety(false);
        for (aabb.min.x..aabb.max.x + 1) |x| {
            const pixel_center = pixelCenter(x, y);

            const edge_results = edgeResults(vertex_positions, pixel_center);

            if (inside(edge_results, top_left)) {
                const barycentric_weights: [3]f32 = barycentricWeights(edge_results, inverse_area);
                const interpolated_varyings = ShaderInput(Varyings, varyings_array, barycentric_weights);
                target.memory[y * target.width + x] = format.pixel(interpolated_varyings.color);
                //shader goes here

            }
        }
    }
}

pub fn ShaderInput(comptime Varyings: type, varyings_array: [3]Varyings, weights: [3]f32) Varyings {
    var out_varyings: Varyings = undefined;
    inline for (comptime std.meta.fields(Varyings)) |field| {
        if (field.type == Color) {
            @field(out_varyings, field.name) = interpolateColor(
                .{
                    @field(varyings_array[0], field.name),
                    @field(varyings_array[1], field.name),
                    @field(varyings_array[2], field.name),
                },
                weights,
            );
        } else {
            @compileError("Unsupported varying type for interpolation");
        }
    }
    return out_varyings;
}

inline fn interpolateColor(colors: [3]Color, weights: [3]f32) Color {
    return .{
        .r = colors[0].r * weights[0] + colors[1].r * weights[1] + colors[2].r * weights[2],
        .g = colors[0].g * weights[0] + colors[1].g * weights[1] + colors[2].g * weights[2],
        .b = colors[0].b * weights[0] + colors[1].b * weights[1] + colors[2].b * weights[2],
        .a = colors[0].a * weights[0] + colors[1].a * weights[1] + colors[2].a * weights[2],
    };
}
inline fn varyingsArray(comptime Varyings: type, vertices: [3]Vertex(Varyings)) [3]Varyings {
    return .{
        vertices[0].varyings,
        vertices[1].varyings,
        vertices[2].varyings,
    };
}
inline fn vertexPositions(vertices: anytype) [3]Vec2f {
    const VertexT = @TypeOf(vertices[0]);

    if (!@hasField(VertexT, "position")) {
        @compileError("Vertex type must have a 'position' field of type Vec2f");
    }
    return .{
        vertices[0].position,
        vertices[1].position,
        vertices[2].position,
    };
}

inline fn topLeftEdges(vertex_positions: [3]Vec2f) [3]bool {
    return .{
        isTopLeftEdge(vertex_positions[0], vertex_positions[1]),
        isTopLeftEdge(vertex_positions[1], vertex_positions[2]),
        isTopLeftEdge(vertex_positions[2], vertex_positions[0]),
    };
}
inline fn edgeResults(vertex_positions: [3]Vec2f, pixel_center: Vec2f) [3]f32 {
    return .{
        edge(vertex_positions[0], vertex_positions[1], pixel_center),
        edge(vertex_positions[1], vertex_positions[2], pixel_center),
        edge(vertex_positions[2], vertex_positions[0], pixel_center),
    };
}

inline fn pixelCenter(x: usize, y: usize) Vec2f {
    return .{
        .x = @as(f32, @floatFromInt(x)) + 0.5,
        .y = @as(f32, @floatFromInt(y)) + 0.5,
    };
}

inline fn triangleAABB(vertices: [3]Vec2f, width: u32, height: u32) AABBu {
    const aabb = AABB.fromPolygon(&vertices);
    const clamp_upper_y: f32 = @floatFromInt(height - 1);
    const clamp_upper_x: f32 = @floatFromInt(width - 1);

    const min_y = ceilClamp(0.0, clamp_upper_y, aabb.min.y - 0.5);
    const max_y = floorClamp(0.0, clamp_upper_y, aabb.max.y + 0.5);

    const max_x = floorClamp(0.0, clamp_upper_x, aabb.max.x + 0.5);
    const min_x = ceilClamp(0.0, clamp_upper_x, aabb.min.x - 0.5);

    return .{
        .min = .{ .x = min_x, .y = min_y },
        .max = .{ .x = max_x, .y = max_y },
    };
}

inline fn barycentricWeights(edge_results: [3]f32, inverse_area: f32) [3]f32 {
    return .{
        edge_results[1] * inverse_area,
        edge_results[2] * inverse_area,
        edge_results[0] * inverse_area,
    };
}

inline fn inside(edge_results: [3]f32, top_left: [3]bool) bool {
    return (edge_results[0] < 0.0 or (edge_results[0] == 0.0 and !top_left[0])) and
        (edge_results[1] < 0.0 or (edge_results[1] == 0.0 and !top_left[1])) and
        (edge_results[2] < 0.0 or (edge_results[2] == 0.0 and !top_left[2]));
}

inline fn isTopLeftEdge(a: Vec2f, b: Vec2f) bool {
    const dy = b.y - a.y;
    const dx = b.x - a.x;
    return (dy < 0) or (dy == 0 and dx > 0);
}
