const std = @import("std");

const alignof = std.mem.Alignment.of;

pub const Vector = @import("Vector.zig");
pub const Matrix = @import("Matrix.zig");

pub const Mat2f = Matrix.Mat(2, f32);
pub const Mat3f = Matrix.Mat(3, f32);
pub const Mat4f = Matrix.Mat(4, f32);

pub const Rect = extern struct {
    half_width: f32,
    half_height: f32,
};
pub fn Vec2(comptime T: type) type {
    return struct {
        const Self = @This();
        x: T,
        y: T,

        pub fn fromSimd(vec: anytype) Self {
            return .{ .x = vec[0], .y = vec[1] };
        }

        pub fn toSimd(self: Self) @Vector(2, T) {
            return .{ self.x, self.y };
        }

        pub fn dot(self: Self, other: Self) f32 {
            return self.x * other.x + self.y * other.y;
        }

        pub fn len(self: Self) f32 {
            return std.math.sqrt(self.dot(self));
        }

        pub fn normalize(self: Self) Self {
            const lenght = self.len();
            return .{ .x = self.x / lenght, .y = self.y / lenght };
        }

        pub fn scale(self: Self, scalar: f32) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar };
        }
    };
}

pub const Vec2f = Vec2(f32);

pub const Transform2D = struct {
    translation: Vec2f,
    scale: Vec2f,
    angle: f32,

    pub fn toMat3(self: Transform2D) Mat3f {
        return .{
            .rows = .{
                .{ @cos(self.angle) * self.scale.x, -@sin(self.angle) * self.scale.y, self.translation.x },
                .{ @sin(self.angle) * self.scale.y, @cos(self.angle) * self.scale.x, self.translation.y },
                .{ 0.0, 0.0, 1.0 },
            },
        };
    }
};
