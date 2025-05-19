const objc = @import("objc");
const Object = objc.Object;

pub const Point = extern struct {
    x: f64,
    y: f64,
};

pub const Size = extern struct {
    width: f64,
    height: f64,
};
pub const Rect = extern struct {
    origin: Point,
    size: Size,
};

pub fn String(string: []const u8) Object {
    return objc.getClass("NSString").?.msgSend(
        Object,
        "stringWithUTF8String:",
        .{string},
    );
}
