const std = @import("std");
const objc = @import("objc");
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
});

const Object = objc.Object;

display_width: u32,
display_height: u32,

pub fn init() @This() {
    const main_screen = objc.getClass("NSScreen").?.msgSend(Object, "mainScreen", .{});
    const frame = main_screen.msgSend(c.CGRect, "convertFromBacking:", .{main_screen.msgSend(c.CGRect, "frame", .{})});

    return .{
        .display_width = @as(u32, @intFromFloat(frame.size.width)),
        .display_height = @as(u32, @intFromFloat(frame.size.height)),
    };
}
