const std = @import("std");
const objc = @import("objc");

const foundation = @import("../Foundation/Foundation.zig");
const Object = foundation.Object;

const class_name = "NSEvent";
const Self = @This();
object: objc.Object,

pub usingnamespace Object.Extend(Self, class_name);

const Mask = packed struct(u64) {
    pub const any: Mask = @as(Mask, @bitCast(@as(u64, std.math.maxInt(u64))));
    _unused_0: bool = false, // bit 0 — unused
    left_mouse_down: bool = false, // bit 1
    left_mouse_up: bool = false, // bit 2
    right_mouse_down: bool = false, // bit 3
    right_mouse_up: bool = false, // bit 4
    mouse_moved: bool = false, // bit 5
    left_mouse_dragged: bool = false, // bit 6
    right_mouse_dragged: bool = false, // bit 7
    mouse_entered: bool = false, // bit 8
    mouse_exited: bool = false, // bit 9
    key_down: bool = false, // bit 10
    key_up: bool = false, // bit 11
    flags_changed: bool = false, // bit 12
    appkit_defined: bool = false, // bit 13
    system_defined: bool = false, // bit 14
    application_defined: bool = false, // bit 15
    periodic: bool = false, // bit 16
    cursor_update: bool = false, // bit 17
    _unused_18: bool = false, // bit 18 — unused
    _unused_19: bool = false, // bit 19 — unused
    _unused_20: bool = false, // bit 20 — unused
    _unused_21: bool = false, // bit 21 — unused
    scroll_wheel: bool = false, // bit 22
    tablet_point: bool = false, // bit 23
    tablet_proximity: bool = false, // bit 24
    other_mouse_down: bool = false, // bit 25
    other_mouse_up: bool = false, // bit 26
    other_mouse_dragged: bool = false, // bit 27
    _unused_28: bool = false, // bit 28 — unused
    gesture: bool = false, // bit 29
    magnify: bool = false, // bit 30
    swipe: bool = false, // bit 31

    // remaining bits (32–63) are not part of standard NSEventMask
    _padding: u32 = 0, // padding to reach 64 bits
};
