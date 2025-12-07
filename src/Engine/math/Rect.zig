const std = @import("std");
const Vector = @import("Vector.zig");
const Vec2f = Vector.Vec2f;

const AABB = @import("AABB.zig");

const Transform2D = @import("Transform.zig").Transform2D;

const Quad2D = @import("math.zig").Quad2D;

const Rect = @This();

half_width: f32,
half_height: f32,

pub fn fullExtents(self: Rect) Rect {
    return .{
        .half_width = self.half_width * 2.0,
        .half_height = self.half_height * 2.0,
    };
}

pub fn quad(self: Rect, transform: Transform2D) Quad2D {
    return .{
        transform.apply(.{ .x = -self.half_width, .y = -self.half_height }), // TL
        transform.apply(.{ .x = -self.half_width, .y = self.half_height }), // BL
        transform.apply(.{ .x = self.half_width, .y = self.half_height }), // BR
        transform.apply(.{ .x = self.half_width, .y = -self.half_height }), // TR
    };
}

pub fn Aabb(self: Rect, transform: Transform2D) AABB {
    const q = self.quad(transform);

    const xs: @Vector(4, f32) = .{ q[0].x, q[1].x, q[2].x, q[3].x };
    const ys: @Vector(4, f32) = .{ q[0].y, q[1].y, q[2].y, q[3].y };

    const max_x = @reduce(.Max, xs);
    const min_x = @reduce(.Min, xs);
    const max_y = @reduce(.Max, ys);
    const min_y = @reduce(.Min, ys);

    return .{
        .max = .{ .x = max_x, .y = max_y },
        .min = .{ .x = min_x, .y = min_y },
    };
}
