const Vector = @import("Vector.zig");
const Matrix = @import("Matrix.zig");

const Vec2f = Vector.Vec2f;
const Vec3f = Vector.Vec3f;
const Mat3f = Matrix.Mat3f;

pub const Transform2D = struct {
    translation: Vec2f,
    rotation: f32,
    scale: Vec2f,

    pub fn mat3(self: Transform2D) Mat3f {
        const c = @cos(self.rotation);
        const s = @sin(self.rotation);

        return .{
            .mat = .{
                .rows = .{
                    .{ c * self.scale.x, s * self.scale.x, 0.0 },
                    .{ -s * self.scale.y, c * self.scale.y, 0.0 },
                    .{ self.translation.x, self.translation.y, 1.0 },
                },
            },
        };
    }

    pub fn apply(self: Transform2D, point: Vec2f) Vec2f {
        const point3: Vec3f = .{
            .x = point.x,
            .y = point.y,
            .z = 1.0,
        };
        const vec3: Vec3f = self.mat3().mulVec(point3);
        return .{
            .x = vec3.x,
            .y = vec3.y,
        };
    }
};
