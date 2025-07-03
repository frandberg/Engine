const objc = @import("objc");
const Object = @import("Object.zig");

const wrap = @import("../optionals.zig").wrap;
const unwrap = @import("../optionals.zig").unwrap;

const class_name = "NSString";
const Self = @This();

object: objc.Object,

pub usingnamespace Object.Extend(Self, class_name);

pub fn @"initWithUTF8String:"(self: Self, nullTerminatedCString: [:0]const u8) ?Self {
    return wrap(Self, self.object.msgSend(objc.Object, "initWithUTF8String:", .{nullTerminatedCString.ptr}));
}
