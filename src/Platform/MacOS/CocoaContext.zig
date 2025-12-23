const std = @import("std");
const objc = @import("objc");

const foundation = @import("foundation");

const Input = foundation.Input;

//extern fn MTLCreateSystemDefaultDevice() objc.c.id;
const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("Carbon/Carbon.h");
});

const log = std.log.scoped(.CocoaContext);
const Atomic = std.atomic.Value;

const CocoaContext = @This();

var is_running: Atomic(bool) = .init(true);

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern const NSDefaultRunLoopMode: objc.c.id;

app: Object,
window: Object,
delegate: Delegate,

pub fn init(window_width: u32, window_height: u32) CocoaContext {
    const delegate = Delegate.init();

    const app = objc.getClass("NSApplication").?.msgSend(Object, "sharedApplication", .{});

    app.msgSend(void, "setActivationPolicy:", .{@as(usize, 0)}); // NSApplicationActivationPolicyRegular
    app.msgSend(void, "setDelegate:", .{delegate.object.value});

    const window_rect = c.CGRectMake(
        0, // x
        0, // y
        @as(c.CGFloat, @floatFromInt(window_width)),
        @as(c.CGFloat, @floatFromInt(window_height)),
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

pub fn view(self: *const CocoaContext) Object {
    return self.window.msgSend(Object, "contentView", .{});
}

pub const Delegate = struct {
    object: Object,

    pub fn init() Delegate {
        const class = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

        _ = class.addMethod("windowShouldClose:", windowShouldClose);

        _ = objc.registerClassPair(class);

        const object = class.msgSend(Object, "new", .{});

        return .{
            .object = object,
        };
    }

    pub fn deinit(self: Delegate) void {
        self.object.msgSend(void, "release", .{});
    }

    fn windowShouldClose(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
        std.debug.print("window closed\n", .{});
        is_running.store(false, .release);
        return true;
    }
};

pub fn processInput(self: *CocoaContext, prev_input: Input) Input {
    const new_input: Input = prev_input;
    while (nextEvent(self.app, 0.001)) |event_id| {
        switch (Object.fromId(event_id).msgSend(usize, "type", .{})) {
            else => self.app.msgSend(void, "sendEvent:", .{event_id}),
        }

        self.app.msgSend(void, "updateWindows", .{});
    }
    return new_input;
}

pub fn isRunning() bool {
    return is_running.load(.acquire);
}

const mask: usize = std.math.maxInt(usize);
fn nextEvent(app: objc.Object, timeout_seconds: f64) ?objc.c.id {
    const until_date: Object = dateSinceNow(timeout_seconds);
    const event = app.msgSend(objc.c.id, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
        mask,
        until_date.value,
        NSDefaultRunLoopMode,
        true,
    });

    if (event != nil) {
        return event;
    }
    return null;
}

fn dateSinceNow(seconds: f64) Object {
    const NSDate = objc.getClass("NSDate").?;
    return NSDate.msgSend(Object, "dateWithTimeIntervalSinceNow:", .{seconds});
}

fn translateKeyCode(key_code: u16) Input.KeyCode {
    return switch (key_code) {
        c.kVK_ANSI_A => .a,
        c.kVK_ANSI_B => .b,
        c.kVK_ANSI_C => .c,
        c.kVK_ANSI_D => .d,
        c.kVK_ANSI_E => .e,
        c.kVK_ANSI_F => .f,
        c.kVK_ANSI_G => .g,
        c.kVK_ANSI_H => .h,
        c.kVK_ANSI_I => .i,
        c.kVK_ANSI_J => .j,
        c.kVK_ANSI_K => .k,
        c.kVK_ANSI_L => .l,
        c.kVK_ANSI_M => .m,
        c.kVK_ANSI_N => .n,
        c.kVK_ANSI_O => .o,
        c.kVK_ANSI_P => .p,
        c.kVK_ANSI_Q => .q,
        c.kVK_ANSI_R => .r,
        c.kVK_ANSI_S => .s,
        c.kVK_ANSI_T => .t,
        c.kVK_ANSI_U => .u,
        c.kVK_ANSI_V => .v,
        c.kVK_ANSI_W => .w,
        c.kVK_ANSI_X => .x,
        c.kVK_ANSI_Y => .y,
        c.kVK_ANSI_Z => .z,

        // Number row
        c.kVK_ANSI_0 => .@"0",
        c.kVK_ANSI_1 => .@"1",
        c.kVK_ANSI_2 => .@"2",
        c.kVK_ANSI_3 => .@"3",
        c.kVK_ANSI_4 => .@"4",
        c.kVK_ANSI_5 => .@"5",
        c.kVK_ANSI_6 => .@"6",
        c.kVK_ANSI_7 => .@"7",
        c.kVK_ANSI_8 => .@"8",
        c.kVK_ANSI_9 => .@"9",

        // Symbols
        c.kVK_ANSI_Grave => .@"`",
        c.kVK_ANSI_Minus => .@"-",
        c.kVK_ANSI_Equal => .@"=",
        c.kVK_ANSI_LeftBracket => .@"[",
        c.kVK_ANSI_RightBracket => .@"]",
        c.kVK_ANSI_Backslash => .@"\\",
        c.kVK_ANSI_Semicolon => .@";",
        c.kVK_ANSI_Quote => .@"'",
        c.kVK_ANSI_Comma => .@",",
        c.kVK_ANSI_Period => .@".",
        c.kVK_ANSI_Slash => .@"/",

        // Whitespace & editing
        c.kVK_Space => .space,
        c.kVK_Return => .enter,
        c.kVK_Tab => .tab,
        c.kVK_Delete => .backspace,
        c.kVK_Escape => .escape,
        c.kVK_ForwardDelete => .delete,

        // Arrows
        c.kVK_LeftArrow => .left,
        c.kVK_RightArrow => .right,
        c.kVK_UpArrow => .up,
        c.kVK_DownArrow => .down,

        // Modifiers
        c.kVK_Shift => .left_shift,
        c.kVK_RightShift => .right_shift,
        c.kVK_Control => .left_ctrl,
        c.kVK_RightControl => .right_ctrl,
        c.kVK_Option => .left_alt,
        c.kVK_RightOption => .right_alt,
        c.kVK_Command => .left_super,
        c.kVK_RightCommand => .right_super,
        c.kVK_Function => .@"fn",
        c.kVK_CapsLock => .capslock,

        // Function keys
        c.kVK_F1 => .f1,
        c.kVK_F2 => .f2,
        c.kVK_F3 => .f3,
        c.kVK_F4 => .f4,
        c.kVK_F5 => .f5,
        c.kVK_F6 => .f6,
        c.kVK_F7 => .f7,
        c.kVK_F8 => .f8,
        c.kVK_F9 => .f9,
        c.kVK_F10 => .f10,
        c.kVK_F11 => .f11,
        c.kVK_F12 => .f12,
        c.kVK_F13 => .f13,
        c.kVK_F14 => .f14,
        c.kVK_F15 => .f15,
        c.kVK_F16 => .f16,
        c.kVK_F17 => .f17,
        c.kVK_F18 => .f18,
        c.kVK_F19 => .f19,
        c.kVK_F20 => .f20,
    };
}
