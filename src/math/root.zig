const std = @import("std");

pub const Vector = @import("Vector.zig");
pub const Matrix = @import("Matrix.zig");
pub const Transform = @import("Transform.zig");

pub const vec = Vector.vec;
pub const simd = Vector.simd;

pub const AABB = @import("AABB.zig");
pub const Mat = Matrix.Mat;

pub const VecT = Vector.VecT;

pub const Vec = Vector.Vec;

pub const Vec2f = Vector.Vec2(f32);
pub const Vec3f = Vector.Vec3(f32);
pub const Vec4f = Vector.Vec4(f32);

pub const Mat3f = Matrix.Mat3(f32);

pub const Transform2D = Transform.Transform2D;
pub const Extents = @import("Extents.zig");

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const Quad2D = [4]Vec2f;
pub const Quad3D = [4]Vec3f;

pub const Clip = @import("Clip.zig");

//A plane defined by a normal and a value d akin to the normal/equation form ax
pub const Line = struct {
    normal: Vec2f,
    d: f32,

    pub fn fromPoints(tail: Vec2f, head: Vec2f) Line {
        const dir_vec = vec(simd(head) - simd(tail));
        const normal: Vec2f = .{
            .x = -dir_vec.y,
            .y = dir_vec.x,
        };
        const d = Vector.dot(normal, tail);
        return .{
            .normal = normal,
            .d = d,
        };
    }
};

pub const Plane = struct {
    normal: Vec3f,
    d: f32,
};

pub const Color = Vector.Color;

pub fn edge(a: Vec2f, b: Vec2f, p: Vec2f) f32 {
    const ab: Vec2f = vec(simd(b) - simd(a));
    const ap: Vec2f = vec(simd(p) - simd(a));
    return Vector.det(ab, ap);
}
