const std = @import("std");

pub const Vector = @import("Vector.zig");
pub const Matrix = @import("Matrix.zig");
pub const Transform = @import("Transform.zig");

pub const vec = Vector.vec;
pub const simd = Vector.simd;

const Aabb = @import("AABB.zig");
pub const AABB = Aabb.AABB(f32);
pub const AABBu = Aabb.AABB(u32);
pub const Mat = Matrix.Mat;

pub const VecT = Vector.VecT;

pub const Vec = Vector.Vec;

pub const Vec2f = Vector.Vec2(f32);
pub const Vec3f = Vector.Vec3(f32);
pub const Vec4f = Vector.Vec4(f32);

pub const Mat3f = Matrix.Mat3(f32);

pub const Transform2D = Transform.Transform2D;
pub const Extents = @import("Extents.zig");

pub const Quad2D = [4]Vec2f;
pub const Quad3D = [4]Vec3f;

pub const Clip = @import("Clip.zig");

pub const Color = Vector.Color;

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn quad(self: *const Rect) Quad2D {
        return .{
            .{ .x = self.x, .y = self.y },
            .{ .x = self.x + self.width, .y = self.y },
            .{ .x = self.x + self.width, .y = self.y + self.height },
            .{ .x = self.x, .y = self.y + self.height },
        };
    }
};

pub fn Size(comptime T: type) type {
    return struct {
        width: T,
        height: T,

        pub fn eql(self: @This(), other: @This()) bool {
            return self.width == other.width and self.height == other.height;
        }

        pub fn isZero(self: @This()) bool {
            return self.width == 0 and self.height == 0;
        }
    };
}

pub fn edge(a: Vec2f, b: Vec2f, p: Vec2f) f32 {
    const ab: Vec2f = vec(simd(b) - simd(a));
    const ap: Vec2f = vec(simd(p) - simd(a));
    return Vector.det(ab, ap);
}

pub const Sizeu = Size(u32);
pub const Sizef = Size(f32);
