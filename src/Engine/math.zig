pub const Vec4 = @Vector(4, f32);
pub const Vec2 = @Vector(2, f32);

pub const Rect = struct {
    pos: Vec2,
    size: Vec2,

    pub inline fn max(self: Rect) Vec2 {
        return self.pos + Vec2{ self.size[0] / 2.0, self.size[1] / 2.0 };
    }

    pub inline fn min(self: Rect) Vec2 {
        return self.pos - Vec2{ self.size[0] / 2.0, self.size[1] / 2.0 };
    }

    pub fn shift(rect: Rect, x: f32, y: f32) Rect {
        return .{
            .pos = .{ rect.pos[0] + x, rect.pos[1] + y },
            .size = rect.size,
        };
    }

    pub fn clip(rect: Rect, min_x: f32, min_y: f32, max_x: f32, max_y: f32) Rect {
        const new_x = @max(min_x, rect.pos[0]);
        const new_y = @max(min_y, rect.pos[1]);
        const new_w = @min(max_x, rect.pos[0] + rect.size[0]) - new_x;
        const new_h = @min(max_y, rect.pos[1] + rect.size[1]) - new_y;

        return .{
            .pos = .{ new_x, new_y },
            .size = .{ if (new_w > 0.0) new_w else 0.0, if (new_h > 0.0) new_h else 0.0 },
        };
    }
};
