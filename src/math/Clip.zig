const std = @import("std");
const AABB = @import("AABB.zig");
const Transform = @import("Transform.zig");
const Transform2D = @import("Transform.zig").Transform2D;
const Vector = @import("Vector.zig");
const Rect = @import("Rect.zig");
const Vec2f = Vector.Vec2f;

const math = @import("root.zig");
const edge = math.edge;

const assert = std.debug.assert;

const vec = Vector.vec;
const simd = Vector.simd;

const Quad2D = math.Quad2D;

//const Line = math.Line;

pub fn quad2DByAABB(quad: Quad2D, aabb: AABB, out_vertices: *[8]Vec2f) []const Vec2f {
    const clip_vertices = aabb.vertices();

    return clip(&quad, &clip_vertices, out_vertices);
}

pub fn clip(
    subject_vertices: []const Vec2f,
    clip_vertices: []const Vec2f,
    out_vertices: []Vec2f,
) []const Vec2f {
    assert(subject_vertices.len >= 3);
    assert(clip_vertices.len >= 3);
    // std.debug.print(
    //     "Clipping polygon with {any} vertices against polygon with {any} vertices\n",
    //     .{ subject_vertices, clip_vertices },
    // );

    // Step 5: copy subject polygon into output buffer
    @memcpy(out_vertices[0..subject_vertices.len], subject_vertices);
    var vertex_count: usize = subject_vertices.len;

    // Loop over each clipping edge
    for (clip_vertices, 0..) |clip_curr, i| {
        const clip_prev = clip_vertices[(i + clip_vertices.len - 1) % clip_vertices.len];

        var new_count: usize = 0;
        var prev_vertex = out_vertices[vertex_count - 1];
        var prev_inside = inside(clip_prev, clip_curr, prev_vertex);

        // Forward traversal, no overwriting unread vertices
        for (out_vertices[0..vertex_count]) |curr_vertex| {
            const curr_inside = inside(clip_prev, clip_curr, curr_vertex);

            if (prev_inside and curr_inside) {
                // Case 1: inside → inside
                out_vertices[new_count] = curr_vertex;
                new_count += 1;
            } else if (prev_inside and !curr_inside) {
                // Case 2: inside → outside
                out_vertices[new_count] = intersect(clip_prev, clip_curr, prev_vertex, curr_vertex);
                new_count += 1;
            } else if (!prev_inside and curr_inside) {
                // Case 3: outside → inside
                out_vertices[new_count] =
                    intersect(clip_prev, clip_curr, prev_vertex, curr_vertex);
                new_count += 1;

                out_vertices[new_count] = curr_vertex;
                new_count += 1;
            }

            prev_vertex = curr_vertex;
            prev_inside = curr_inside;
        }

        // Entire polygon clipped away

        if (new_count == 0) {
            @panic("No new vertices");
            //    return out_vertices[0..0];
        }

        // Update count for next clip edge
        vertex_count = new_count;
    }

    return out_vertices[0..vertex_count];
}

inline fn inside(tail: Vec2f, head: Vec2f, point: Vec2f) bool {
    return edge(tail, head, point) <= 0.0;
}

fn intersect(tail_a: Vec2f, head_a: Vec2f, tail_b: Vec2f, head_b: Vec2f) Vec2f {
    const area_a: f32 = edge(tail_a, head_a, tail_b);
    const area_b: f32 = edge(tail_a, head_a, head_b);

    const t: f32 = area_a / (area_a - area_b);
    const t_simd: Vec2f.Simd = @splat(t);
    const b_simd: Vec2f.Simd = simd(head_b) - simd(tail_b);
    return vec(simd(tail_b) + t_simd * b_simd);
}
