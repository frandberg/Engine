const std = @import("std");
const objc = @import("objc");
const ns = @import("Cocoa.zig");

const Object = objc.Object;
const Id = objc.c.id;

const Runtime = struct {
    window: Object,
    view: Object,
};

pub fn init(self_id: Id, _: objc.c.SEL, _: Id) callconv(.c) void {
    std.debug.print("app init\n", .{});

    app().msgSend(void, "activateIgnoringOtherApps:", .{true});

    const MTKView = objc.getClass("MTKView").?;
    const self = Object{ .value = self_id };
    const runtime = std.heap.page_allocator.create(Runtime) catch @panic("OOM");
    const window = initWindow(800, 600);
    const frame = window.msgSend(ns.Rect, "frame", .{});
    const view = MTKView.msgSend(Object, "alloc", .{}).msgSend(Object, "initWithFrame:", .{
        frame,
    });

    const layer = view.msgSend(Object, "layer", .{});

    window.msgSend(void, "setDelegate:", .{self});
    window.msgSend(void, "makeKeyAndOrderFront:", .{null});
    window.msgSend(void, "setContentView:", .{view});

    view.msgSend(void, "setDelegate:", .{self});
    view.msgSend(void, "wantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{layer});

    runtime.* = .{
        .window = window,
        .view = view,
    };

    _ = objc.c.object_setInstanceVariable(self_id, "runtime", runtime);
}

pub fn initWindow(width: f64, height: f64) objc.Object {
    const NSWindow = objc.getClass("NSWindow").?;

    const style_mask: usize = 1 | (1 << 1) | (1 << 2) | (1 << 3);
    const rect: ns.Rect = .{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .size = .{
            .width = width,
            .height = height,
        },
    };
    const window = NSWindow.msgSend(objc.Object, "alloc", .{}).msgSend(
        objc.Object,
        "initWithContentRect:styleMask:backing:defer:",
        .{
            rect,
            style_mask,
            2, //NSBackingStoreBuffer
            false, //defer
        },
    );

    return window;
}

pub fn getRuntime(delegate: Id) *Runtime {
    var tmp: ?*anyopaque = null;
    _ = objc.c.object_getInstanceVariable(delegate, "runtime", @ptrCast(&tmp));
    return @alignCast(@ptrCast(tmp.?));
}
pub fn app() Object {
    const NSApplication: objc.Class = objc.getClass("NSApplication").?;
    return NSApplication.msgSend(Object, "sharedApplication", .{});
}

pub fn step(self: Id, _sel: objc.c.SEL, view: Id) callconv(.c) void {
    _ = self;
    _ = _sel;
    _ = view;
    //    std.debug.print("ticked\n", .{});
}
pub fn onResize(self: Id, _: objc.c.SEL, view: Id, size: ns.Size) callconv(.c) void {
    std.debug.print("changed size: {}, {}\n", .{ size.width, size.height });
    _ = self;
    _ = view;
}
pub fn shouldCloseAfterWindows(_: Id, _: objc.c.SEL) callconv(.c) bool {
    return true;
}

pub fn createDelegate() !Object {
    const DelegateClass = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

    if (!try DelegateClass.addMethod("applicationDidFinishLaunching:", init)) {
        std.debug.print("failed to add app init\n", .{});
    }

    if (!try DelegateClass.addMethod("drawInMTKView:", step)) {
        std.debug.print("failed to add app quit\n", .{});
    }

    if (!try DelegateClass.addMethod("mtkView:drawableSizeWillChange:", onResize)) {
        std.debug.print("failed to add size change\n", .{});
    }

    if (!try DelegateClass.addMethod("applicationShouldTerminateAfterLastWindowClosed:", shouldCloseAfterWindows)) {
        std.debug.print("failed to add app quit\n", .{});
    }

    if (!objc.c.class_addIvar(
        DelegateClass.value,
        "runtime",
        @sizeOf(*anyopaque),
        @alignOf(*anyopaque),
        "^v",
    )) {
        std.debug.print("failed to add struct\n", .{});
    }
    const AppProto = objc.getProtocol("NSApplicationDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, AppProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }

    const WndProto = objc.getProtocol("NSWindowDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, WndProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }

    const ViewProto = objc.getProtocol("MTKViewDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, ViewProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }
    objc.registerClassPair(DelegateClass);
    const delegate = DelegateClass.msgSend(Object, "alloc", .{}).msgSend(Object, "init", .{});
    return delegate;
}
