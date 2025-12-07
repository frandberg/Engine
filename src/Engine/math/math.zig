const std = @import("std");

const Vector = @import("Vector.zig");
const Matrix = @import("Matrix.zig");
const Transform = @import("Transform.zig");

pub const vec = Vector.vec;
pub const simd = Vector.simd;

pub const AABB = @import("AABB.zig");
pub const Mat = Matrix.Mat;

pub const VecT = Vector.VecT;

pub const Vec = Vector.Vec;

pub const Vec2f = Vector.Vec2(f32);
pub const Vec3f = Vector.Vec3(f32);
pub const Vec4f = Vector.Vec4(f32);

pub const Mat2f = Matrix.Mat(2, f32);
pub const Mat3f = Matrix.Mat(3, f32);
pub const Mat4f = Matrix.Mat(4, f32);

pub const Transform2D = Transform.Transform2D;
pub const Rect = @import("Rect.zig");

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

pub inline fn signedArea(a: Vec2f, b: Vec2f) f32 {
    return a.x * b.y - a.y * b.x;
}

pub fn edge(a: Vec2f, b: Vec2f, p: Vec2f) f32 {
    const ab: Vec2f = vec(simd(b) - simd(a));
    const ap: Vec2f = vec(simd(p) - simd(a));
    return signedArea(ab, ap);
}
