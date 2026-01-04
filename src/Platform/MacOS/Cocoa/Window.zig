const std = @import("std");
const objc = @import("objc");
const c = @import("../c.zig").c;
const core = @import("core");

const nil: Object = .{ .value = @ptrFromInt(0) };

const Application = @import("Application.zig");

const Object = objc.Object;
const Class = objc.Class;

const Window = @This();

window: Object,
delegate: Delegate,

pub fn init(spec: core.WindowSpec) Window {
    const delegate: Delegate = .init();
    errdefer delegate.deinit();

    const window_style: usize = 15;
    const backing_store_buffered = 2;

    const rect: c.CGRect = .{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{
            .width = @floatFromInt(spec.width),
            .height = @floatFromInt(spec.height),
        },
    };

    const window = objc.getClass("NSWindow").?.msgSend(
        Object,
        "alloc",
        .{},
    ).msgSend(
        Object,
        "initWithContentRect:styleMask:backing:defer:",
        .{
            rect,
            window_style,
            backing_store_buffered,
            false, // d
        },
    );
    errdefer window.msgSend(void, "release", .{});

    window.msgSend(void, "setDelegate:", .{delegate.delegate});
    window.msgSend(void, "makeKeyAndOrderFront:", .{nil});

    return .{
        .window = window,
        .delegate = delegate,
    };
}

pub fn deinit(self: Window) void {
    self.delegate.deinit();
    self.window.msgSend(void, "release", .{});
}

pub fn attachLayer(self: Window, layer: Object) void {
    const view = self.window.msgSend(Object, "contentView", .{});
    view.msgSend(void, "setWantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{layer});

    const size = view.msgSend(c.CGRect, "bounds", .{}).size;
    layer.msgSend(void, "setDrawableSize:", .{size});
}

const Delegate = struct {
    delegate: Object,

    pub fn init() Delegate {
        const Cls: Class = createClass();
        const delegate: Object = Cls.msgSend(Object, "new", .{});
        return .{
            .delegate = delegate,
        };
    }

    pub fn deinit(self: Delegate) void {
        self.delegate.msgSend(void, "release", .{});
    }

    fn createClass() Class {
        const class = objc.allocateClassPair(objc.getClass("NSObject"), "WindowDelegate").?;

        _ = class.addMethod("windowShouldClose:", windowShouldClose);

        _ = objc.registerClassPair(class);
        return class;
    }

    fn windowShouldClose(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
        Application.quit();
        return true;
    }
};
