const buitin = @import("builtin");
const ptr_bit_width = buitin.target.ptrBitWidth();
pub const Float = if (ptr_bit_width == 64) f64 else if (ptr_bit_width) f32 else @compileError("non standard cpu bit widht");

pub const Point = extern struct {
    x: Float,
    y: Float,
};

pub const Size = extern struct {
    width: Float,
    height: Float,
};

pub const Rect = extern struct {
    origin: Point,
    size: Size,
};
