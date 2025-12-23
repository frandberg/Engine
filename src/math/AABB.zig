const std = @import("std");

const math = @import("root.zig");
const Vec2f = math.Vec2f;
const Vec3f = math.Vec3f;
const Extents = math.Extents;
const Mat3f = math.Mat3f;

const Transform2D = math.Transform2D;

const vec = math.vec;
const simd = math.simd;

const AABB = @This();

max: Vec2f,
min: Vec2f,

pub fn vertices(self: AABB) [4]Vec2f {
    return .{
        .{ .x = self.min.x, .y = self.min.y }, // TL
        .{ .x = self.min.x, .y = self.max.y }, // BL
        .{ .x = self.max.x, .y = self.max.y }, // BR
        .{ .x = self.max.x, .y = self.min.y }, // TR
    };
}

pub fn fromExtents(extents: Extents, transform: math.Mat3f) AABB {
    const corners: [4]Vec2f = .{
        transform.mulVec2(Vec3f{ .x = extents.half_width, .y = extents.half_height }),
        transform.mulVec2(Vec3f{ .x = extents.half_width, .y = -extents.half_height }),
        transform.mulVec2(Vec3f{ .x = -extents.half_width, .y = extents.half_height }),
        transform.mulVec2(Vec3f{ .x = -extents.half_width, .y = -extents.half_height }),
    };
    return fromPolygon(&corners);
}

pub fn rectAABB(transform: Transform2D) AABB {
    const half_size: Vec2f = vec(simd(transform.scale) / @as(Vec2f.Simd, @splat(2.0)));
    const pos: Vec2f = transform.translation;
    const corners: [4]Vec3f = .{
        .{ .x = pos.x - half_size.x, .y = pos.y - half_size.y, .z = 1.0 },
        .{ .x = pos.x + half_size.x, .y = pos.y - half_size.y, .z = 1.0 },
        .{ .x = pos.x + half_size.x, .y = pos.y + half_size.y, .z = 1.0 },
        .{ .x = pos.x - half_size.x, .y = pos.y + half_size.y, .z = 1.0 },
    };
    return fromPolygon(&corners);
}

pub inline fn fromPolygon(corners: anytype) AABB {
    std.debug.assert(corners.len > 2);
    var max: Vec2f = .{ .x = -std.math.inf(f32), .y = -std.math.inf(f32) };
    var min: Vec2f = .{ .x = std.math.inf(f32), .y = std.math.inf(f32) };

    inline for (corners) |corner| {
        min.x = @min(corner.x, min.x);
        min.y = @min(corner.y, min.y);

        max.x = @max(corner.x, max.x);
        max.y = @max(corner.y, max.y);
    }

    return .{
        .max = max,
        .min = min,
    };
}

pub fn overlaps(a: AABB, b: AABB) bool {
    return !(a.min.x > b.max.x or
        a.max.x < b.min.x or
        a.min.y > b.max.y or
        a.max.y < b.min.y);
}

pub fn pointInAabb(aabb: AABB, point: Vec2f) bool {
    return (point.x >= aabb.min.x and point.x <= aabb.max.x) and
        (point.y >= aabb.min.y and point.y <= aabb.max.y);
}
