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

    pub fn clip(rect: Rect, min_x: f32, min_y: f32, max_x: f32, max_y: f32) Rect {
        const new_x = @max(min_x, rect.x);
        const new_y = @max(min_y, rect.y);
        const new_w = @min(max_x, rect.x + rect.width) - new_x;
        const new_h = @min(max_y, rect.y + rect.height) - new_y;

        return .{
            .x = new_x,
            .y = new_y,
            .width = if (new_w > 0.0) new_w else 0.0,
            .height = if (new_h > 0.0) new_h else 0.0,
        };
    }
};
