pub const KeyCode = enum {
    // letters
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    // numbers (top row)
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",

    // symbols (main section)
    @"`", // grave / tilde
    @"-", // minus / underscore
    @"=", // equal / plus
    @"[", // left bracket / {
    @"]", // right bracket / }
    @"\\", // backslash / |
    @";", // semicolon / :
    @"'", // single quote / "
    @",", // comma / <
    @".", // period / >
    @"/", // slash / ?

    // function keys
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    // navigation
    up,
    down,
    left,
    right,
    home,
    end,
    pageup,
    pagedown,
    insert,
    delete,

    // other
    space,
    tab,
    enter,
    backspace,
    escape,
    printscreen,
    scrolllock,
    pause,
    menu,

    left_ctrl,
    right_ctrl,
    left_shift,
    right_shift,
    left_alt,
    right_alt,
    left_super,
    right_super,
    @"fn",
    capslock,
};
