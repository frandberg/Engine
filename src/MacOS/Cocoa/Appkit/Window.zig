const objc = @import("objc");

const foundation = @import("../Foundation/Foundation.zig");
const Responder = @import("Responder.zig");
const UInteger = foundation.UInteger;
const Rect = foundation.Rect;

const wrap = @import("../optionals.zig").wrap;
const unwrap = @import("../optionals.zig").unwrap;

const class_name = "NSWindow";
const Self = @This();
pub usingnamespace Responder.Extend(Self, class_name);

object: objc.Object,

pub fn @"initWithContentRect:styleMask:backing:defer"(self: Self, contentRect: Rect, styleMask: StyleMask, backing: BackingStoreType, @"defer": bool) ?Self {
    return wrap(Self, self.object.msgSend(objc.Object, "initWithContentRect:styleMask:backing:defer:", .{
        contentRect,
        @as(u64, @bitCast(styleMask)),
        backing,
        @"defer",
    }));
}

pub fn makeKeyAndOrderFront(self: Self, sender: ?objc.Object) void {
    self.object.msgSend(void, "makeKeyAndOrderFront:", .{unwrap(sender)});
}

const StyleMask = packed struct(u64) {
    titled: bool = false, // bit 0
    closable: bool = false, // bit 1
    miniaturizable: bool = false, // bit 2
    resizable: bool = false, // bit 3
    utility_window: bool = false, // bit 4
    _unused_5: bool = false, // bit 5 — unused
    doc_modal_window: bool = false, // bit 6
    nonactivating_panel: bool = false, // bit 7
    _unused_8: bool = false, // bit 8 — texturedBackground (deprecated)
    _unused_9: bool = false, // bit 9
    _unused_10: bool = false, // bit 10
    _unused_11: bool = false, // bit 11
    unified_title_and_toolbar: bool = false, // bit 12
    hud_window: bool = false, // bit 13
    full_screen: bool = false, // bit 14
    full_size_content_view: bool = false, // bit 15

    _padding: u48 = 0, // padding
};
const BackingStoreType = enum(UInteger) {
    retained = 0,
    nonretained = 1,
    buffered = 2,
    _,
};
