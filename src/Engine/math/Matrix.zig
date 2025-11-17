const std = @import("std");

pub const Mat2f = Mat(2, f32);
pub const Mat3f = Mat(3, f32);
pub const Mat4f = Mat(4, f32);

// Sqaure Matrix, 2x2, 3x3 or 4x4
pub fn Mat(comptime N: comptime_int, comptime ElementT: type) type {
    return struct {
        const Self = @This();
        pub const VecT = @Vector(N, ElementT);

        rows: [N]VecT,

        pub fn column(self: Self, index: comptime_int) VecT {
            var result: VecT = undefined;
            inline for (0..N) |row_index| {
                result[row_index] = self.rows[row_index][index];
            }
            return result;
        }

        pub fn identity() Self {
            var result: Self = undefined;
            for (0..N) |i| {
                for (0..N) |j| {
                    if (i == j) {
                        result.rows[i][j] = 1;
                    } else {
                        result.rows[i][j] = 0;
                    }
                }
            }
        }

        pub fn mul(self: Self, other: Self) Self {
            var result: Self = undefined;
            inline for (self.rows, 0..) |row, row_index| {
                inline for (0..N) |col_index| {
                    result.rows[row_index][col_index] = Vector.dot(row, other.column(col_index));
                }
            }
            return result;
        }

        pub fn mulVec(self: Self, vec: VecT) VecT {
            var result: VecT = undefined;
            inline for (self.rows, 0..) |row, i| {
                result[i] = Vector.dot(row, vec);
            }
            return result;
        }
    };
}

const Vector = @import("Vector.zig");
const Vec2f = Vector.Vec2f;
const Vec3f = Vector.Vec3f;
const Vec4f = Vector.Vec4f;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
test "matrix test" {
    const a = Mat2f{
        .rows = .{
            .{ 1.0, 2.0 },
            .{ 3.0, 4.0 },
        },
    };

    const b = Mat2f{
        .rows = .{
            .{ 3.0, 4.0 },
            .{ 2.0, 1.0 },
        },
    };

    const vec: Vec2f = .{ 1.0, 2.0 };

    const result_mat = a.mul(b);
    const result_vec: Vec2f = a.mulVec(vec);

    try expectEqual(result_mat.rows[0], .{ 7.0, 6.0 });
    try expectEqual(result_mat.rows[1], .{ 17.0, 16.0 });
    try expectEqual(result_vec, .{ 5.0, 11.0 });
}
