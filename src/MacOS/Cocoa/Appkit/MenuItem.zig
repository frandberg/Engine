const objc = @import("objc");
const Menu = @import("Menu.zig");

const foundation = @import("../Foundation/Foundation.zig");
const Object = foundation.Object;

const Self = @This();
const class_name = "NSMenuItem";

object: objc.Object,
pub usingnamespace Object.Extend(Self, class_name);

pub fn setSubmenu(self: Self, submenu: Menu.Self) void {
    self.object.msgSend(void, "setSubmenu:", .{submenu.object.value});
}
