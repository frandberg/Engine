const std = @import("std");

const Vector = @import("Vector.zig");
const Matrix = @import("Matrix.zig");

pub const vec = Vector.vec;
pub const simd = Vector.simd;

pub const Mat = Matrix.Mat;

pub const VecT = Vector.VecT;

pub const Vec2f = Vector.Vec2(f32);
pub const Vec3f = Vector.Vec3(f32);
pub const Vec4f = Vector.Vec4(f32);

pub const Mat2f = Matrix.Mat(2, f32);
pub const Mat3f = Matrix.Mat(3, f32);
pub const Mat4f = Matrix.Mat(4, f32);

pub const Rect = extern struct {
    half_width: f32,
    half_height: f32,
};

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Transform2D = struct {
    translation: Vec2f,
    scale: Vec2f,
    angle: f32,

    pub fn mat3(self: Transform2D) Mat3f {
        return .{
            .rows = .{
                .{ @cos(self.angle) * self.scale.x, -@sin(self.angle) * self.scale.y, self.translation.x },
                .{ @sin(self.angle) * self.scale.y, @cos(self.angle) * self.scale.x, self.translation.y },
                .{ 0.0, 0.0, 1.0 },
            },
        };
    }
};
