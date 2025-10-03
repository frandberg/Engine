const std = @import("std");
const Input = @This();

keys_state: Keys = .{},
pub const Packed = packed struct(u128) {
    key_state: Keys = .{},
    _padding: u28 = 0,
};

pub fn fromPacked(packed_input: Packed) Input {
    return .{
        .keys_state = packed_input.key_state,
    };
}

pub fn toPacked(input: Input) Packed {
    return .{
        .key_state = input.keys_state,
    };
}

pub const KeyCodes: type = std.meta.FieldEnum(Keys);
pub const Keys = packed struct(u100) {
    // letters
    a: bool = false,
    b: bool = false,
    c: bool = false,
    d: bool = false,
    e: bool = false,
    f: bool = false,
    g: bool = false,
    h: bool = false,
    i: bool = false,
    j: bool = false,
    k: bool = false,
    l: bool = false,
    m: bool = false,
    n: bool = false,
    o: bool = false,
    p: bool = false,
    q: bool = false,
    r: bool = false,
    s: bool = false,
    t: bool = false,
    u: bool = false,
    v: bool = false,
    w: bool = false,
    x: bool = false,
    y: bool = false,
    z: bool = false,

    // numbers (top row)
    @"0": bool = false,
    @"1": bool = false,
    @"2": bool = false,
    @"3": bool = false,
    @"4": bool = false,
    @"5": bool = false,
    @"6": bool = false,
    @"7": bool = false,
    @"8": bool = false,
    @"9": bool = false,

    // symbols (main section)
    @"`": bool = false, // grave / tilde
    @"-": bool = false, // minus / underscore
    @"=": bool = false, // equal / plus
    @"[": bool = false, // left bracket / {
    @"]": bool = false, // right bracket / }
    @"\\": bool = false, // backslash / |
    @";": bool = false, // semicolon / :
    @"'": bool = false, // single quote / "
    @",": bool = false, // comma / <
    @".": bool = false, // period / >
    @"/": bool = false, // slash / ?

    // function keys
    f1: bool = false,
    f2: bool = false,
    f3: bool = false,
    f4: bool = false,
    f5: bool = false,
    f6: bool = false,
    f7: bool = false,
    f8: bool = false,
    f9: bool = false,
    f10: bool = false,
    f11: bool = false,
    f12: bool = false,
    f13: bool = false,
    f14: bool = false,
    f15: bool = false,
    f16: bool = false,
    f17: bool = false,
    f18: bool = false,
    f19: bool = false,
    f20: bool = false,
    f21: bool = false,
    f22: bool = false,
    f23: bool = false,
    f24: bool = false,

    // navigation
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    home: bool = false,
    end: bool = false,
    pageup: bool = false,
    pagedown: bool = false,
    insert: bool = false,
    delete: bool = false,

    // other
    space: bool = false,
    tab: bool = false,
    enter: bool = false,
    backspace: bool = false,
    escape: bool = false,
    printscreen: bool = false,
    scrolllock: bool = false,
    pause: bool = false,
    menu: bool = false,

    left_ctrl: bool = false,
    right_ctrl: bool = false,
    left_shift: bool = false,
    right_shift: bool = false,
    left_alt: bool = false,
    right_alt: bool = false,
    left_super: bool = false,
    right_super: bool = false,
    @"fn": bool = false,
    capslock: bool = false,
};
