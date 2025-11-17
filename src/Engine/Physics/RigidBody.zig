const math = @import("math");
const Vec2f = math.Vec2f;
const Rect = math.Rect;

pub const Shape = union(enum) {
    rect: Rect,
    line: void,
};

shape: Shape,
velocity: Vec2f = .{ .x = 0.0, .y = 0.0 },
acceleration: Vec2f = .{ .x = 0.0, .y = 0.0 },
