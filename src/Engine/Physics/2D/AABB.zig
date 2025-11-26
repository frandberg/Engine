const std = @import("std");
const math = @import("math");
const Vec2f = math.Vec2f;
const Rect = math.Rect;
const Mat3f = math.Mat3f;

const vec = math.vec;

const AABB = @This();

max: Vec2f,
min: Vec2f,

pub fn rectAabb(rect: Rect, transform: math.Mat3f) AABB {
    const corners: [4]math.Vec3f = .{
        vec(transform.mulVec(.{ rect.half_width, rect.half_height, 1.0 })),
        vec(transform.mulVec(.{ rect.half_width, -rect.half_height, 1.0 })),
        vec(transform.mulVec(.{ -rect.half_width, rect.half_height, 1.0 })),
        vec(transform.mulVec(.{ -rect.half_width, -rect.half_height, 1.0 })),
    };
    var max: Vec2f = .{ .x = -std.math.inf(f32), .y = -std.math.inf(f32) };
    var min: Vec2f = .{ .x = std.math.inf(f32), .y = std.math.inf(f32) };

    inline for (corners) |corner| {
        if (corner[0] < min.x) min.x = corner[0];
        if (corner[1] < min.y) min.y = corner[1];

        if (corner[0] > max.x) max.x = corner[0];
        if (corner[1] > max.y) max.y = corner[1];
    }

    return .{
        .max = max,
        .min = min,
    };
}
