const objc = @import("objc");
const Object = @import("Object.zig");
const class_name = "NSDate";

const wrap = @import("../optionals.zig").wrap;
const unwrap = @import("../optionals.zig").unwrap;

const Self = @This();

object: objc.Object,

pub usingnamespace Object.Extend(Self, class_name);
pub fn distantPast() ?Self {
    return wrap(Self, objc.getClass(class_name).?.msgSend(objc.Object, "distantPast", .{}));
}
