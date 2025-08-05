const std = @import("std");
const objc = @import("objc");
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
});

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

display_width: u32,
display_height: u32,

pub fn init() @This() {
    const main_screen = objc.getClass("NSScreen").?.msgSend(Object, "mainScreen", .{});
    std.debug.assert(main_screen.value != nil);
    const frame = main_screen.msgSend(c.CGRect, "convertRectToBacking:", .{main_screen.msgSend(c.CGRect, "frame", .{})});

    return .{
        .display_width = @as(u32, @intFromFloat(frame.size.width)),
        .display_height = @as(u32, @intFromFloat(frame.size.height)),
    };
}
