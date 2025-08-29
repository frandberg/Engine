const std = @import("std");
const objc = @import("objc");

const common = @import("common");

extern fn MTLCreateSystemDefaultDevice() objc.c.id;
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

const log = std.log.scoped(.CocoaContext);

const CocoaContext = @This();

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern const NSDefaultRunLoopMode: objc.c.id;

const AtomicBool = std.atomic.Value(bool);

app: Object,
window: Object,
delegate: Delegate,

pub const Size = struct {
    width: u32,
    height: u32,
};

pub fn init(window_size: Size, layer: Object) CocoaContext {
    const delegate = Delegate.init();

    const app = objc.getClass("NSApplication").?.msgSend(Object, "sharedApplication", .{});

    app.msgSend(void, "setActivationPolicy:", .{@as(usize, 0)}); // NSApplicationActivationPolicyRegular
    app.msgSend(void, "setDelegate:", .{delegate.object.value});

    const window_rect = c.CGRectMake(
        0, // x
        0, // y
        @as(c.CGFloat, @floatFromInt(window_size.width)),
        @as(c.CGFloat, @floatFromInt(window_size.height)),
    );

    // const screen = objc.getClass("NSScreen").?.msgSend(Object, "mainScreen", .{});
    // const window_rect_in_pts = screen.msgSend(c.CGRect, "convertRectFromBacking:", .{window_rect});

    const window = objc.getClass("NSWindow").?.msgSend(
        Object,
        "alloc",
        .{},
    ).msgSend(
        Object,
        "initWithContentRect:styleMask:backing:defer:",
        .{
            window_rect,
            @as(usize, 15), // NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
            @as(usize, 2), // NSBackingStoreBuffered
            false, // d
        },
    );

    errdefer window.msgSend(void, "release", .{});

    window.msgSend(void, "setDelegate:", .{delegate.object.value});
    window.msgSend(void, "makeKeyAndOrderFront:", .{nil});

    const view: Object = window.msgSend(Object, "contentView", .{});

    view.msgSend(void, "setWantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{layer.value});
    const bounds = view.msgSend(c.CGRect, "bounds", .{});
    layer.msgSend(void, "setDrawableSize:", .{bounds.size});

    app.msgSend(void, "finishLaunching", .{});
    app.msgSend(void, "activateIgnoringOtherApps:", .{true});

    return .{
        .app = app,
        .window = window,
        .delegate = delegate,
    };
}

pub fn deinit(self: *const CocoaContext) void {
    self.delegate.deinit();
    self.window.msgSend(void, "release", .{});
}
pub fn windowViewSize(self: *const CocoaContext) Size {
    // const screen = objc.getClass("NSScreen").?.msgSend(Object, "mainScreen", .{});
    const view = self.window.msgSend(Object, "contentView", .{});

    const bounds: c.CGRect = view.msgSend(c.CGRect, "bounds", .{});

    return .{
        .width = @intFromFloat(bounds.size.width),
        .height = @intFromFloat(bounds.size.height),
    };
}

pub const Delegate = struct {
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
        return true;
    }

    fn windowDidResize(delegate: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) void {
        var flags = flagsPtr(delegate);
        flags.window_resized = true;
    }
};

pub fn processEvents(self: *CocoaContext) void {
    while (nextEvent(self.app, 0.001)) |event_id| {
        const event = objc.Object.fromId(event_id);
        if (event.msgSend(usize, "type", .{}) == 10) {
            const key_code = event.msgSend(u16, "keyCode", .{});
            if (key_code == 0) {
                log.info("A key pressed", .{});
            }
        }
        self.app.msgSend(void, "sendEvent:", .{event_id});
        self.app.msgSend(void, "updateWindows", .{});
    }
}

const mask: usize = std.math.maxInt(usize);
fn nextEvent(app: objc.Object, timeout_seconds: f64) ?objc.c.id {
    const until_date: objc.c.id = dateSinceNow(timeout_seconds);
    const event = app.msgSend(objc.c.id, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
        mask,
        until_date,
        NSDefaultRunLoopMode,
        true,
    });

    if (event != nil) {
        return event;
    }
    return null;
}

fn dateSinceNow(seconds: f64) objc.c.id {
    const NSDate = objc.getClass("NSDate").?;
    return NSDate.msgSend(objc.c.id, "dateWithTimeIntervalSinceNow:", .{seconds});
}
