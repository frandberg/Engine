const std = @import("std");
const objc = @import("objc");
const Object = objc.Object;
const Id = objc.c.id;

pub const UInteger = u64;
pub const Integer = i64;
pub const Float = f64;

pub const Point = extern struct {
    x: Float,
    y: Float,
};

pub const Size = extern struct {
    width: Float,
    height: Float,
};
pub const Rect = extern struct {
    origin: Point,
    size: Size,
};

pub fn String(string: []const u8) Object {
    return objc.getClass("NSString").?.msgSend(
        Object,
        "stringWithUTF8String:",
        .{string},
    );
}
pub const App = struct {
    object: Object,

    pub fn init() App {
        const NSApplicationClass = objc.getClass("NSApplication").?;
        const app = NSApplicationClass.msgSend(Object, "sharedApplication", .{});

        app.msgSend(void, "setActivationPolicy:", .{@as(Integer, 0)});
        app.msgSend(void, "finishLaunching", .{});
        return app;
    }

    pub fn updateWindows(self: App) void {
        self.object.msgSend(void, "updateWindows", .{});
    }

    extern var NSDefaultRunLoopMode: Id;
    pub fn getNextEvent(self: App) ?Event {
        const event = self.object.msgSend(Object, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
            Event.mask,
            @as(usize, 0),
            NSDefaultRunLoopMode,
            true,
        });
        if (event.value == @as(objc.c.id, @ptrFromInt(0))) {
            return null;
        }
        const event_type: Event.Type = @enumFromInt(event.getProperty(UInteger, "type"));
        return switch (event_type) {
            .key_down => .{
                .key_down = @enumFromInt(event.getProperty(u16, "keyCode")),
            },
            .key_up => .{
                .key_up = @enumFromInt(event.getProperty(u16, "keyCode")),
            },
            else => blk: {
                self.object.msgSend(void, "sendEvent:", .{event});
                break :blk null;
            },
        };
    }

    fn didFinLaunch(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) void {
        const app = App.get();
        std.debug.print("activating\n", .{});
        app.object.msgSend(void, "activateIgnoringOtherApps:", .{true});
    }
};
pub const Window = struct {
    object: Object,
    const StyleMask = packed struct(UInteger) {
        titled: u1 = 0,
        closable: u1 = 0,
        miniaturizable: u1 = 0,
        resizable: u1 = 0,
        utility_window: u1 = 0,
        _unused_bit_1: u1 = 0,
        dec_modal_window: u1 = 0,
        non_activating_panel: u1 = 0,
        _unused_bits_2: u5 = 0,
        hud_window: u1 = 0,
        full_dcreen: u1 = 0,
        _padding: u49 = 0,
    };

    pub fn init(
        title: []const u8,
        width: u32,
        height: u32,
        x: u32,
        y: u32,
        style_mask: StyleMask,
    ) Window {
        const NSWindow = objc.getClass("NSWindow").?;
        const NSScreen = objc.getClass("NSScreen").?;
        const scale_factor: Float = NSScreen.msgSend(Object, "mainScreen", .{})
            .msgSend(
            Float,
            "backingScaleFactor",
            .{},
        );

        const scaled_width = @as(Float, @floatFromInt(width)) / scale_factor;
        const scaled_height = @as(Float, @floatFromInt(height)) / scale_factor;

        const scaled_x = @as(Float, @floatFromInt(x)) / scale_factor;
        const scaled_y = @as(Float, @floatFromInt(y)) / scale_factor;

        const rect: Rect = .{
            .size = .{
                .width = scaled_width,
                .height = scaled_height,
            },
            .origin = .{
                .x = scaled_x,
                .y = scaled_y,
            },
        };
        const NSBackingStoreBuffered: UInteger = 2;

        const window = NSWindow
            .msgSend(Object, "alloc", .{})
            .msgSend(Object, "initWithContentRect:styleMask:backing:defer:", .{
            rect,
            style_mask,
            NSBackingStoreBuffered,
            false, // defer
        });
        window.setProperty("title", String(title));
        return .{ .object = window };
    }
    pub fn makeKeyandOrderFront(self: Window) void {
        self.object.msgSend(void, "makeKeyAndOrderFront:", .{@as(objc.c.id, 0)});
    }
};
pub const Event = union(enum) {
    key_down: KeyCode,
    key_up: KeyCode,

    const Type = enum(UInteger) {
        key_down = 10,
        key_up = 11,
        _,
    };

    const mask: UInteger = std.math.maxInt(UInteger);

    pub const KeyCode = enum(u16) {
        a = 0,
        s = 1,
        d = 2,
        f = 3,
        h = 4,
        g = 5,
        z = 6,
        x = 7,
        c = 8,
        v = 9,
        section = 10,
        b = 11,
        q = 12,
        w = 13,
        e = 14,
        r = 15,
        y = 16,
        t = 17,
        @"1" = 18,
        @"2" = 19,
        @"3" = 20,
        @"4" = 21,
        @"6" = 22,
        @"5" = 23,
        equal = 24,
        @"9" = 25,
        @"7" = 26,
        minus = 27,
        @"8" = 28,
        @"0" = 29,
        right_bracket = 30,
        o = 31,
        u = 32,
        left_bracket = 33,
        i = 34,
        p = 35,
        return_key = 36,
        l = 37,
        j = 38,
        apostrophe = 39,
        k = 40,
        semicolon = 41,
        backslash = 42,
        comma = 43,
        slash = 44,
        n = 45,
        m = 46,
        period = 47,
        tab = 48,
        space = 49,
        backtick = 50,
        delete = 51,
        escape = 53,

        command = 55,
        shift = 56,
        caps_lock = 57,
        option = 58,
        control = 59,
        right_shift = 60,
        right_option = 61,
        right_control = 62,
        function = 63,

        f17 = 64,
        keypad_decimal = 65,
        keypad_multiply = 67,
        keypad_plus = 69,
        keypad_clear = 71,
        keypad_divide = 75,
        keypad_enter = 76,
        keypad_minus = 78,
        keypad_equals = 81,
        keypad_0 = 82,
        keypad_1 = 83,
        keypad_2 = 84,
        keypad_3 = 85,
        keypad_4 = 86,
        keypad_5 = 87,
        keypad_6 = 88,
        keypad_7 = 89,
        keypad_8 = 91,
        keypad_9 = 92,

        f5 = 96,
        f6 = 97,
        f7 = 98,
        f3 = 99,
        f8 = 100,
        f9 = 101,
        f11 = 103,
        f13 = 105,
        f16 = 106,
        f14 = 107,
        f10 = 109,
        f12 = 111,
        f15 = 113,

        help = 114,
        home = 115,
        page_up = 116,
        forward_delete = 117,
        f4 = 118,
        end = 119,
        f2 = 120,
        page_down = 121,
        f1 = 122,

        left_arrow = 123,
        right_arrow = 124,
        down_arrow = 125,
        up_arrow = 126,
        _,
    };
};
