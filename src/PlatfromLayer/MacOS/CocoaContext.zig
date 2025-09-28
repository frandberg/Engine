const std = @import("std");
const objc = @import("objc");

const common = @import("common");
const engine = @import("Engine");

const Input = engine.Input;

extern fn MTLCreateSystemDefaultDevice() objc.c.id;
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("Carbon/Carbon.h");
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
        self.app.msgSend(void, "sendEvent:", .{event_id});
        self.app.msgSend(void, "updateWindows", .{});
        if (Object.fromId(event_id).msgSend(usize, "type", .{}) == 10) {
            // toggleKey(input, Object.fromId(event_id).msgSend(u16, "keyCode", .{}), true);
        }
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

fn toggleKey(input: *Input, key_code: u16, pressed: bool) void {
    switch (key_code) {
        c.kVK_ANSI_A => input.keys_down.a = pressed,
        c.kVK_ANSI_B => input.keys_down.b = pressed,
        c.kVK_ANSI_C => input.keys_down.c = pressed,
        c.kVK_ANSI_D => input.keys_down.d = pressed,
        c.kVK_ANSI_E => input.keys_down.e = pressed,
        c.kVK_ANSI_F => input.keys_down.f = pressed,
        c.kVK_ANSI_G => input.keys_down.g = pressed,
        c.kVK_ANSI_H => input.keys_down.h = pressed,
        c.kVK_ANSI_I => input.keys_down.i = pressed,
        c.kVK_ANSI_J => input.keys_down.j = pressed,
        c.kVK_ANSI_K => input.keys_down.k = pressed,
        c.kVK_ANSI_L => input.keys_down.l = pressed,
        c.kVK_ANSI_M => input.keys_down.m = pressed,
        c.kVK_ANSI_N => input.keys_down.n = pressed,
        c.kVK_ANSI_O => input.keys_down.o = pressed,
        c.kVK_ANSI_P => input.keys_down.p = pressed,
        c.kVK_ANSI_Q => input.keys_down.q = pressed,
        c.kVK_ANSI_R => input.keys_down.r = pressed,
        c.kVK_ANSI_S => input.keys_down.s = pressed,
        c.kVK_ANSI_T => input.keys_down.t = pressed,
        c.kVK_ANSI_U => input.keys_down.u = pressed,
        c.kVK_ANSI_V => input.keys_down.v = pressed,
        c.kVK_ANSI_W => input.keys_down.w = pressed,
        c.kVK_ANSI_X => input.keys_down.x = pressed,
        c.kVK_ANSI_Y => input.keys_down.y = pressed,
        c.kVK_ANSI_Z => input.keys_down.z = pressed,

        // Number row
        c.kVK_ANSI_0 => input.keys_down.@"0" = pressed,
        c.kVK_ANSI_1 => input.keys_down.@"1" = pressed,
        c.kVK_ANSI_2 => input.keys_down.@"2" = pressed,
        c.kVK_ANSI_3 => input.keys_down.@"3" = pressed,
        c.kVK_ANSI_4 => input.keys_down.@"4" = pressed,
        c.kVK_ANSI_5 => input.keys_down.@"5" = pressed,
        c.kVK_ANSI_6 => input.keys_down.@"6" = pressed,
        c.kVK_ANSI_7 => input.keys_down.@"7" = pressed,
        c.kVK_ANSI_8 => input.keys_down.@"8" = pressed,
        c.kVK_ANSI_9 => input.keys_down.@"9" = pressed,

        // Symbols
        c.kVK_ANSI_Grave => input.keys_down.@"`" = pressed,
        c.kVK_ANSI_Minus => input.keys_down.@"-" = pressed,
        c.kVK_ANSI_Equal => input.keys_down.@"=" = pressed,
        c.kVK_ANSI_LeftBracket => input.keys_down.@"[" = pressed,
        c.kVK_ANSI_RightBracket => input.keys_down.@"]" = pressed,
        c.kVK_ANSI_Backslash => input.keys_down.@"\\" = pressed,
        c.kVK_ANSI_Semicolon => input.keys_down.@";" = pressed,
        c.kVK_ANSI_Quote => input.keys_down.@"'" = pressed,
        c.kVK_ANSI_Comma => input.keys_down.@"," = pressed,
        c.kVK_ANSI_Period => input.keys_down.@"." = pressed,
        c.kVK_ANSI_Slash => input.keys_down.@"/" = pressed,

        // Whitespace & editing
        c.kVK_Space => input.keys_down.space = pressed,
        c.kVK_Return => input.keys_down.enter = pressed,
        c.kVK_Tab => input.keys_down.tab = pressed,
        c.kVK_Delete => input.keys_down.backspace = pressed,
        c.kVK_Escape => input.keys_down.escape = pressed,
        c.kVK_ForwardDelete => input.keys_down.delete = pressed,

        // Arrows
        c.kVK_LeftArrow => input.keys_down.left = pressed,
        c.kVK_RightArrow => input.keys_down.right = pressed,
        c.kVK_UpArrow => input.keys_down.up = pressed,
        c.kVK_DownArrow => input.keys_down.down = pressed,

        // Modifiers
        c.kVK_Shift => input.keys_down.left_shift = pressed,
        c.kVK_RightShift => input.keys_down.right_shift = pressed,
        c.kVK_Control => input.keys_down.left_ctrl = pressed,
        c.kVK_RightControl => input.keys_down.right_ctrl = pressed,
        c.kVK_Option => input.keys_down.left_alt = pressed,
        c.kVK_RightOption => input.keys_down.right_alt = pressed,
        c.kVK_Command => input.keys_down.left_super = pressed,
        c.kVK_RightCommand => input.keys_down.right_super = pressed,
        c.kVK_Function => input.keys_down.@"fn" = pressed,
        c.kVK_CapsLock => input.keys_down.capslock = pressed,

        // Function keys
        c.kVK_F1 => input.keys_down.f1 = pressed,
        c.kVK_F2 => input.keys_down.f2 = pressed,
        c.kVK_F3 => input.keys_down.f3 = pressed,
        c.kVK_F4 => input.keys_down.f4 = pressed,
        c.kVK_F5 => input.keys_down.f5 = pressed,
        c.kVK_F6 => input.keys_down.f6 = pressed,
        c.kVK_F7 => input.keys_down.f7 = pressed,
        c.kVK_F8 => input.keys_down.f8 = pressed,
        c.kVK_F9 => input.keys_down.f9 = pressed,
        c.kVK_F10 => input.keys_down.f10 = pressed,
        c.kVK_F11 => input.keys_down.f11 = pressed,
        c.kVK_F12 => input.keys_down.f12 = pressed,
        c.kVK_F13 => input.keys_down.f13 = pressed,
        c.kVK_F14 => input.keys_down.f14 = pressed,
        c.kVK_F15 => input.keys_down.f15 = pressed,
        c.kVK_F16 => input.keys_down.f16 = pressed,
        c.kVK_F17 => input.keys_down.f17 = pressed,
        c.kVK_F18 => input.keys_down.f18 = pressed,
        c.kVK_F19 => input.keys_down.f19 = pressed,
        c.kVK_F20 => input.keys_down.f20 = pressed,
        else => if (pressed) {
            log.debug("unknown key pressed", .{});
        } else {
            log.debug("unknown key released", .{});
        },
    }
}
