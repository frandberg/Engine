const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");
const common = @import("common");

extern fn MTLCreateSystemDefaultDevice() objc.c.id;
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

const Delegate = @This();

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const AtomicBool = std.atomic.Value(bool);

const Flags = packed struct(u64) {
    window_closed: bool = false,
    window_resized: bool = false,
    window_minimized: bool = false,
    _reserved: u61 = 0,
};

object: Object,

pub fn init() Delegate {
    const class = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

    _ = try class.addMethod("windowShouldClose:", windowShouldClose);

    _ = try class.addMethod("windowDidResize:", windowDidResize);

    const flag_encoding = comptime objc.comptimeEncode(u64);
    _ = objc.c.class_addIvar(
        class.value,
        "flags",
        @sizeOf(u64),
        @alignOf(u64),
        &flag_encoding,
    );
    // _ = objc.c.class_addIvar(class.value, "framebuffer_size", @sizeOf(*anyopaque), @alignOf(*anyopaque), "^v");

    _ = objc.registerClassPair(class);

    const object = class.msgSend(Object, "new", .{});
    _ = objc.c.object_setInstanceVariable(
        object.value,
        "flags",
        @constCast(&@as(u64, 0)),
    );

    return .{
        .object = object,
    };
}

pub fn deinit(self: Delegate) void {
    self.object.msgSend(void, "release", .{});
}

fn flagsPtr(delegate: objc.c.id) *Flags {
    const class = objc.c.object_getClass(delegate).?;

    const ivar = objc.c.class_getInstanceVariable(class, "flags");

    const offset: usize = @intCast(objc.c.ivar_getOffset(ivar));

    return @ptrFromInt(@as(usize, @intFromPtr(delegate)) + offset);
}

pub fn closed(self: Delegate) bool {
    if (flagsPtr(self.object.value).window_closed) {
        return true;
    }
    return false;
}

pub fn checkAndClearResized(self: Delegate) bool {
    var flags = flagsPtr(self.object.value);
    if (flags.window_resized) {
        flags.window_resized = false;
        return true;
    }
    return false;
}

fn windowShouldClose(delegate: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
    var flags = flagsPtr(delegate);
    flags.window_closed = true;
    std.debug.print("Window should close\n", .{});
    return true;
}

fn windowDidResize(delegate: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) void {
    var flags = flagsPtr(delegate);
    flags.window_resized = true;
    std.debug.print("Window resized\n", .{});
}
