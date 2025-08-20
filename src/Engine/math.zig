pub const Vec4 = @Vector(4, f32);

pub const Rect = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn shift(rect: Rect, x: f32, y: f32) Rect {
        return .{
            .x = rect.x + x,
            .y = rect.y + y,
            .width = rect.width,
            .height = rect.height,
        };
    }

    pub fn clamp(rect: Rect, min_x: f32, min_y: f32, max_x: f32, max_y: f32) Rect {
        return .{
            .x = @max(min_x, @min(max_x, rect.x)),
            .y = @max(min_y, @min(max_y, rect.y)),
            .width = @max(0.0, @min(max_x - rect.x, rect.width)),
            .height = @max(0.0, @min(max_y - rect.y, rect.height)),
        };
    }
};
