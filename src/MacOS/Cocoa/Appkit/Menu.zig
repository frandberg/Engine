const objc = @import("objc");
const MenuItem = @import("MenuItem.zig");

const wrap = @import("../optionals.zig").wrap;

const foundation = @import("../Foundation/Foundation.zig");
const Object = foundation.Object;

const Self = @This();

object: objc.Object,

pub usingnamespace Object.Extend(Self, "NSMenu");
pub fn addItem(self: Self, newItem: MenuItem) void {
    return wrap(self.object.msgSend(void, "addItem:", .{newItem.object.value}));
}
