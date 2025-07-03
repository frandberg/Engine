const std = @import("std");
const objc = @import("objc");
const foundation = @import("../Foundation/Foundation.zig");

const wrap = @import("../optionals.zig").wrap;
const unwrap = @import("../optionals.zig").unwrap;

const Object = foundation.Object;

const UInteger = foundation.UInteger;
const Integer = foundation.Integer;

const Date = foundation.Date;
const String = foundation.String;
const Rect = foundation.Rect;

extern const NSDefaultRunLoopMode: objc.c.id;
pub fn DefaultRunLoopMode() String {
    return .{ .object = .{ .value = NSDefaultRunLoopMode } };
}

pub const MenuItem = struct {
    const class_name = "NSMenuItem";
    const Self = @This();

    object: objc.Object,
    pub usingnamespace Object.Extend(Self, class_name);

    pub fn setSubmenu(self: Self, submenu: Menu.Self) void {
        self.object.msgSend(void, "setSubmenu:", .{submenu.object.value});
    }
};
