const std = @import("std");
const objc = @import("objc");

const log = std.log.scoped(.MetalContext);
const assert = std.debug.assert;

const c = @import("../c.zig").c;

const CGSize = extern struct {
    width: f64,
    height: f64,
};

const Size = struct {
    width: u32,
    height: u32,
};

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern fn MTLCreateSystemDefaultDevice() objc.c.id;

const MetalContext = @This();

const MTLSize = extern struct {
    width: usize,
    height: usize,
    depth: usize,
};

const MTLOrigin = extern struct {
    x: usize,
    y: usize,
    z: usize,
};

device: Object,
command_queue: Object,

pub fn init() MetalContext {
    const device = Object.fromId(MTLCreateSystemDefaultDevice());
    assert(device.value != nil);

    const command_queue: Object = device.msgSend(
        Object,
        "newCommandQueue",
        .{},
    );
    assert(command_queue.value != nil);
    errdefer command_queue.msgSend(void, "release", .{});

    return .{
        .device = device,
        .command_queue = command_queue,
    };
}

pub fn deinit(self: *const MetalContext) void {
    self.command_queue.msgSend(void, "release", .{});
}
