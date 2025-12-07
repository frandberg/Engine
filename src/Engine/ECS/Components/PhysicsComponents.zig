const math = @import("math");
const Vec2f = math.Vec2f;
const Rect = math.Rect;

pub const RigidBody2D = struct {
    pub const Shape = union(enum) {
        rect: Rect,
    };

    shape: Shape,
    velocity: Vec2f,
    acceleration: Vec2f = .{ .x = 0.0, .y = 0.0 },
};
