const std = @import("std");
const objc = @import("objc");

const core = @import("core");

const Input = core.Input;
const EventBuffers = Input.EventBuffers;
const Event = Input.Event;
const Window = @import("Window.zig");

//extern fn MTLCreateSystemDefaultDevice() objc.c.id;

const log = std.log.scoped(.CocoaContext);
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;
const Application = @This();

const CocoaEvents = @import("Events.zig");

const Object = objc.Object;
const Class = objc.Class;
const nil: Object = .{ .value = @ptrFromInt(0) };
extern const NSDefaultRunLoopMode: objc.c.id;

var is_running: Atomic(bool) = .init(true);

app: Object,
main_window: Window,
delegate: Delegate,
event_buffers: EventBuffers,

pub fn init(gpa: Allocator, window_spec: core.WindowSpec) !Application {
    const app = objc.getClass("NSApplication").?.msgSend(Object, "sharedApplication", .{});
    app.msgSend(void, "setActivationPolicy:", .{@as(usize, 0)}); // NSApplicationActivationPolicyRegular

    const delegate: Delegate = .init();
    errdefer delegate.deinit();

    app.msgSend(void, "setDelegate:", .{delegate.delegate});

    const event_bffers: EventBuffers = try .init(gpa);
    errdefer event_bffers.deinit();

    const main_window = Window.init(window_spec);

    app.msgSend(void, "finishLaunching", .{});
    app.msgSend(void, "activateIgnoringOtherApps:", .{true});

    return .{
        .app = app,
        .main_window = main_window,
        .delegate = delegate,
        .event_buffers = event_bffers,
    };
}

pub fn deinit(self: *Application) void {
    self.event_buffers.deinit();
    self.delegate.deinit();
}

pub fn isRunning() bool {
    return is_running.load(.acquire);
}

pub fn quit() void {
    is_running.store(false, .release);
}

pub fn pollEvents(self: *Application) !void {
    while (CocoaEvents.next(self.app)) |event| {
        if (CocoaEvents.decode(event)) |e| {
            try self.event_buffers.pushEvent(e);
        } else {}

        self.app.msgSend(void, "sendEvent:", .{event});
        self.app.msgSend(void, "updateWindows", .{});
    }
}

const Delegate = struct {
    delegate: Object,

    pub fn init() Delegate {
        const Cls: Class = createClass();
        const delegate: Object = Cls.msgSend(Object, "new", .{});
        return .{
            .delegate = delegate,
        };
    }

    pub fn deinit(self: Delegate) void {
        self.delegate.msgSend(void, "release", .{});
    }

    fn createClass() Class {
        const class = objc.allocateClassPair(objc.getClass("NSObject"), "AppDelegate").?;

        _ = class.addMethod("applicationShouldTerminate:", applicationShouldTerminate);

        _ = objc.registerClassPair(class);
        return class;
    }

    fn applicationShouldTerminate(_: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) bool {
        quit();
        return true;
    }
};
