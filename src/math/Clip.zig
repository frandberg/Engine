const std = @import("std");
const AABB = @import("AABB.zig");
const Transform = @import("Transform.zig");
const Transform2D = @import("Transform.zig").Transform2D;
const Vector = @import("Vector.zig");
const Vec2f = Vector.Vec2f;
const Matrix = @import("Matrix.zig");
const Mat3f = Matrix.Mat3f;

const math = @import("root.zig");
const edge = math.edge;

const assert = std.debug.assert;
const log = std.log.scoped(.math);
const FixedBufferAllocator = std.heap.FixedBufferAllocator;

const vec = Vector.vec;
const simd = Vector.simd;

const Quad2D = math.Quad2D;

pub fn quad2DByAABB(quad: Quad2D, aabb: AABB, out_vertices: *[8]Vec2f) []Vec2f {
    const clip_vertices = aabb.quad(Mat3f.identity());

    const buffer_size = @sizeOf(Vec2f) * 2 * 2 * 8;
    var buffer: [buffer_size]u8 = undefined;
    var fba = FixedBufferAllocator.init(&buffer);

    const result = clip(fba.allocator(), &quad, &clip_vertices) catch @panic("falied to clip");

    @memcpy(
        out_vertices[0..result.len],
        result,
    );
    return out_vertices[0..result.len];
}

pub fn clip(
    allocator: std.mem.Allocator,
    subject: []const Vec2f,
    clip_poly: []const Vec2f,
) ![]Vec2f {
    std.debug.assert(subject.len >= 3);
    std.debug.assert(clip_poly.len >= 3);

    const capacity = 2 * subject.len;

    var buf_a = try std.ArrayList(Vec2f).initCapacity(allocator, capacity);
    var buf_b = try std.ArrayList(Vec2f).initCapacity(allocator, capacity);
    errdefer buf_a.deinit(allocator);
    errdefer buf_b.deinit(allocator);

    // Initial polygon = subject
    try buf_a.appendSliceBounded(subject);

    var in_buf = &buf_a;
    var out_buf = &buf_b;

    for (clip_poly, 0..) |clip_curr, i| {
        const clip_prev = clip_poly[(i + clip_poly.len - 1) % clip_poly.len];

        out_buf.clearRetainingCapacity();

        const in_len = in_buf.items.len;
        if (in_len == 0) break;

        var prev = in_buf.items[in_len - 1];
        var prev_inside = inside(clip_prev, clip_curr, prev);

        for (in_buf.items) |curr| {
            const curr_inside = inside(clip_prev, clip_curr, curr);

            if (prev_inside and curr_inside) {
                // inside → inside
                try out_buf.appendBounded(curr);
            } else if (prev_inside and !curr_inside) {
                // inside → outside
                try out_buf.appendBounded(intersect(
                    clip_prev,
                    clip_curr,
                    prev,
                    curr,
                ));
            } else if (!prev_inside and curr_inside) {
                // outside → inside
                try out_buf.appendBounded(intersect(
                    clip_prev,
                    clip_curr,
                    prev,
                    curr,
                ));
                try out_buf.appendBounded(curr);
            }

            prev = curr;
            prev_inside = curr_inside;
        }

        // swap buffers
        std.mem.swap(*std.ArrayList(Vec2f), &in_buf, &out_buf);
    }

    // Return a copy owned by allocator
    return try in_buf.toOwnedSlice(allocator);
}

inline fn inside(tail: Vec2f, head: Vec2f, point: Vec2f) bool {
    return edge(tail, head, point) >= 0.0;
}

fn intersect(tail_a: Vec2f, head_a: Vec2f, tail_b: Vec2f, head_b: Vec2f) Vec2f {
    const area_a: f32 = edge(tail_a, head_a, tail_b);
    const area_b: f32 = edge(tail_a, head_a, head_b);

    const t: f32 = area_a / (area_a - area_b);
    const t_simd: Vec2f.Simd = @splat(t);
    const b_simd: Vec2f.Simd = simd(head_b) - simd(tail_b);
    return vec(simd(tail_b) + t_simd * b_simd);
}
