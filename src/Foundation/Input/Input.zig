const std = @import("std");
const Input = @This();

pub const KeyCode = @import("KeyCodes.zig").KeyCode;

pub const EventKind = enum {
    key_down,
    key_up,
};

pub const Event = union(EventKind) {
    key_down: KeyCode,
    key_up: KeyCode,
};
