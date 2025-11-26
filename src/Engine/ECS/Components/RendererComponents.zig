const math = @import("math.zig");

pub const ColorSprite = struct {
    rect: math.Rect(f32),
    color: math.Color,
};
