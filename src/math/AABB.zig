const std = @import("std");

const math = @import("root.zig");
const Vec2f = math.Vec2f;
const Vec3f = math.Vec3f;
const Extents = math.Extents;
const Mat3f = math.Mat3f;
const Vector = math.Vector;
const Vec2 = Vector.Vec2;

const Transform2D = math.Transform2D;

const vec = math.vec;
const simd = math.simd;

pub fn AABB(comptime T: type) type {
    return struct {
        const Self = @This();

        max: Vec2(T),
        min: Vec2(T),

        pub fn quad(self: Self, transform: Mat3f) math.Quad2D {
            return self.getExtents().quad(transform);
        }

        pub fn getExtents(self: Self) Extents {
            return Extents.fromFull(self.max.x - self.min.x, self.max.y - self.min.y);
        }

        pub fn fromExtents(extents: Extents, transform: math.Mat3f) Self {
            const corners: math.Quad2D = extents.quad(transform);
            return fromPolygon(&corners);
        }

        pub fn fromRect(rect: math.Rect) Self {
            return .{
                .max = .{ .x = rect.x + rect.width, .y = rect.y + rect.height },
                .min = .{ .x = rect.x, .y = rect.y },
            };
        }

        pub fn rectAABB(transform: Transform2D) Self {
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

        pub inline fn fromPolygon(corners: anytype) Self {
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

        pub fn overlaps(a: Self, b: Self) bool {
            return !(a.min.x > b.max.x or
                a.max.x < b.min.x or
                a.min.y > b.max.y or
                a.max.y < b.min.y);
        }

        pub fn pointInAabb(aabb: Self, point: Vec2(T)) bool {
            return (point.x >= aabb.min.x and point.x <= aabb.max.x) and
                (point.y >= aabb.min.y and point.y <= aabb.max.y);
        }
    };
}
