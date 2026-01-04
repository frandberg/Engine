const std = @import("std");
const objc = @import("objc");
const c = @import("../c.zig").c;
const core = @import("core");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayListUnmanaged;

const Input = core.Input;
const Event = Input.Event;
const EventKind = Input.EventKind;
const EventBuffers = Input.EventBuffers;

const Atomic = std.atomic.Value;

extern const NSDefaultRunLoopMode: objc.c.id;

const Self = @This();

const Object = objc.Object;

const nil: objc.c.id = @ptrFromInt(0);

const CocoaEventKind = enum(u8) {
    key_down = 10,
    key_up = 11,
    _,

    const mask: u64 = blk: {
        var m: u64 = 0;
        for (std.meta.fields(CocoaEventKind)) |field| {
            m |= 1 << @as(u8, @intCast(field.value));
        }
        break :blk m;
    };
};

const CocoaEvent = union(CocoaEventKind) {
    key_down: Input.KeyCode,
    key_up: Input.KeyCode,
};

pub fn next(app: Object) ?Object {
    const mask: u64 = std.math.maxInt(u64);
    const event = app.msgSend(Object, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
        mask,
        nil,
        NSDefaultRunLoopMode,
        true,
    });
    if (event.value == nil) {
        return null;
    } else {
        return event;
    }
}

pub fn decode(event: Object) ?Event {
    const event_kind: CocoaEventKind = @enumFromInt(event.msgSend(u64, "type", .{}));

    return switch (event_kind) {
        .key_down => .{ .key_down = translateKeyCode(event.msgSend(u16, "keyCode", .{})) },
        .key_up => .{ .key_up = translateKeyCode(event.msgSend(u16, "keyCode", .{})) },
        _ => null,
    };
}

//pub fn getEvents(self: *const Self, allocator: Allocator) ![]Input.Event {}

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

        else => std.debug.panic("invalid keycode: {}\n", .{key_code}),
    };
}
