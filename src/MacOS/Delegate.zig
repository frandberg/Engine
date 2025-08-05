const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

extern fn MTLCreateSystemDefaultDevice() objc.c.id;
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const AtomicBool = std.atomic.Value(bool);
const AtomicSize = @import("FramebufferPool.zig").AtomicSize;

pub fn init(running: *AtomicBool) Object {
    const class = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

    _ = try class.addMethod("windowShouldClose:", windowShouldClose);

    _ = try class.addMethod("windowDidResize:", windowDidResize);

    _ = objc.c.class_addIvar(class.value, "running", @sizeOf(*anyopaque), @alignOf(*anyopaque), "^v");
    // _ = objc.c.class_addIvar(class.value, "framebuffer_size", @sizeOf(*anyopaque), @alignOf(*anyopaque), "^v");

    _ = objc.registerClassPair(class);

    const delegate = class.msgSend(Object, "new", .{});
    _ = objc.c.object_setInstanceVariable(
        delegate.value,
        "running",
        running,
    );

    return delegate;
}
fn windowShouldClose(delegate: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
    std.debug.print("Window should close\n", .{});
    const running = blk: {
        var r: ?*AtomicBool = null;
        _ = objc.c.object_getInstanceVariable(
            delegate,
            "running",
            &r,
        );
        break :blk r.?;
    };
    running.store(false, .seq_cst);
    std.debug.print("Setting running to false\n", .{});

    return true;
}

fn windowDidResize(_: objc.c.id, _: objc.c.SEL, notification: objc.c.id) callconv(.c) void {
    const window = Object.fromId(notification).msgSend(Object, "object", .{});
    const bounds = window.msgSend(Object, "contentView", .{}).msgSend(c.CGRect, "bounds", .{});
    std.debug.print("Window did resize: {}\n", .{bounds.size.width});
}
