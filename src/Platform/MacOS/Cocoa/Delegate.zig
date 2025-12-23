const std = @import("std");
const objc = @import("objc");
const Object = objc.Object;
const Class = objc.Class;

const Events = @import("Events.zig");
const EventKind = Events.Kind;

const Atomic = std.atomic.Value;

const nil: objc.c.id = @ptrFromInt(0);

const c = @import("c.zig");

const Delegate = @This();

var is_running: Atomic(bool) = .init(true);

object: Object,

pub fn init() Delegate {
    const class = createClass();
    const object = class.msgSend(Object, "new", .{});

    return .{
        .object = object,
    };
}

pub fn deinit(self: Delegate) void {
    self.object.msgSend(void, "release", .{});
}

pub fn isRunning() bool {
    return is_running.load(.acquire);
}

fn createClass() Class {
    const class = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

    _ = class.addMethod("windowShouldClose:", windowShouldClose);

    _ = class.addMethod("applicationShouldTerminate:", applicationShouldTerminate);

    _ = objc.registerClassPair(class);
    return class;
}

fn windowShouldClose(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
    is_running.store(false, .release);
    return true;
}

fn applicationShouldTerminate(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) usize {
    is_running.store(false, .release);
    const NSTerminateNow: usize = 0;
    return NSTerminateNow;
}

// fn sendClosedEvent() void {
//     const app = objc.getClass("NSApplication").?
//         .msgSend(Object, "sharedApplication", .{});
//
//     const subtype_shutdown: u16 = 1;
//
//     const event = objc.getClass("NSEvent").?
//         .msgSend(
//         Object,
//         "otherEventWithType:location:modifierFlags:timestamp:windowNumber:context:subtype:data1:data2:",
//         .{
//             @intFromEnum(.closed), // NSEventTypeApplicationDefined
//             c.CGPoint{ .x = 0, .y = 0 },
//             @as(usize, 0),
//             @as(f64, 0),
//             @as(usize, 0),
//             nil,
//             subtype_shutdown,
//             @as(usize, 0),
//             @as(usize, 0),
//         },
//     );
//
//     app.msgSend(void, "postEvent:atStart:", .{ event.value, true });
//}
