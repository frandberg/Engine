const math = @import("math");
const Transform2D = math.Transform2D;
const Matrix = math.Matrix;

const vec = math.vec;
const simd = math.simd;

const Camera = @This();

pub const OrthographicSpec = struct {
    height: f32,
};

pub const Kind = union(enum) {
    orthographic: OrthographicSpec,
};

pub fn viewProjection(self: Camera, left: f32, right: f32, top: f32, bottom: f32) math.Mat3f {
    const projection = switch (self.kind) {
        .orthographic => Matrix.ortho2D(left, right, bottom, top),
    };

    const view: Transform2D = .{
        .translation = vec(-simd(self.transform.translation)),
        .rotation = -self.transform.rotation,
        .scale = .{
            .x = 1.0 / self.transform.scale.x,
            .y = 1.0 / self.transform.scale.y,
        },
    };
    const view_mat = view.mat3();

    return view_mat.mul(projection);
}

transform: Transform2D,
kind: Kind,
near: f32,
far: f32,
