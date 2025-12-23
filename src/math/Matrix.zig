const std = @import("std");
const assert = std.debug.assert;

const VecT = @import("Vector.zig").VecT;

pub const Mat3f = Mat3(f32);

pub fn Mat3(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const SimdT = Mat(3, T).SimdT;

        mat: Mat(3, T),

        pub fn mulVec2(self: Self, vec: Vector.Vec2(T)) Vector.Vec2(T) {
            const result = self.mat.mulVec(Vector.Vec3(T){ .x = vec.x, .y = vec.y, .z = 1 });
            return .{
                .x = result[0],
                .y = result[1],
            };
        }

        pub fn mulVec3(self: Self, vec: Vector.Vec3(T)) Vector.Vec3(T) {
            return self.mat.mulVec(vec);
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{
                .mat = self.mat.mul(other.mat),
            };
        }

        pub fn identity() Self {
            return .{
                .mat = Mat(3, T).identity(),
            };
        }
    };
}

// Sqaure Matrix, 2x2, 3x3 or 4x4
pub fn Mat(comptime N: comptime_int, comptime T: type) type {
    comptime assert((@typeInfo(T) == .float) or (@typeInfo(T) == .int));
    return struct {
        const Self = @This();
        pub const SimdT = @Vector(N, T);

        rows: [N]SimdT,

        pub fn column(self: Self, index: comptime_int) SimdT {
            var result: SimdT = undefined;
            inline for (0..N) |row_index| {
                result[row_index] = self.rows[row_index][index];
            }
            return result;
        }

        pub fn identity() Self {
            var result: Self = undefined;
            inline for (0..N) |i| {
                for (0..N) |j| {
                    if (i == j) {
                        result.rows[i][j] = 1;
                    } else {
                        result.rows[i][j] = 0;
                    }
                }
            }
            return result;
        }

        pub fn mul(self: Self, other: Self) Self {
            var result: Self = undefined;
            inline for (self.rows, 0..) |row, row_index| {
                inline for (0..N) |col_index| {
                    result.rows[row_index][col_index] = @reduce(.Add, row * other.column(col_index));
                }
            }
            return result;
        }

        pub fn mulVec(self: Self, vec: anytype) Self.SimdT {
            const simd_vec: SimdT = if (comptime Vector.is_simd(@TypeOf(vec)))
                vec
            else if (comptime Vector.is_vec(@TypeOf(vec)))
                Vector.simd(vec)
            else
                @compileError("mulVec expects a vector type");

            var result: SimdT = undefined;
            inline for (self.rows, 0..) |row, i| {
                result[i] = @reduce(.Add, row * simd_vec);
            }
            return result;
        }
    };
}

pub fn ortho2D(left: f32, right: f32, top: f32, bottom: f32) Mat3f {
    return Mat3f{
        .mat = .{
            .rows = .{
                .{ 2.0 / (right - left), 0.0, -(right + left) / (right - left) },
                .{ 0.0, 2.0 / (top - bottom), -(top + bottom) / (top - bottom) },
                .{ 0.0, 0.0, 1.0 },
            },
        },
    };
}

const Vector = @import("Vector.zig");
const Vec2f = Vector.Vec2f;
const Vec3f = Vector.Vec3f;
const Vec4f = Vector.Vec4f;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
