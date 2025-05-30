const std = @import("std");
const objc = @import("objc");
const ns = @import("Cocoa.zig");
const c = objc.c;

const Object = objc.Object;
const Id = objc.c.id;

var running: bool = false;

extern const NSApp: Id;
extern var NSDefaultRunLoopMode: Id;

fn windowWillClose(_: Id, _: c.SEL, _: Id) callconv(.c) void {
    running = false;
}
pub fn main() !void {
    const NSApplicationClass = objc.getClass("NSApplication").?;
    const app = NSApplicationClass.msgSend(Object, "sharedApplication", .{});

    app.msgSend(void, "setActivationPolicy:", .{@as(ns.Integer, 0)});
    app.msgSend(void, "finishLaunching", .{});

    const NSSCreenClass = objc.getClass("NSScreen").?;
    const main_screen = NSSCreenClass.msgSend(Object, "mainScreen", .{});
    const backing_scale_factor = main_screen.msgSend(ns.Float, "backingScaleFactor", .{});

    const rect: ns.Rect = .{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .size = .{
            .width = 800 / backing_scale_factor,
            .height = 600 / backing_scale_factor,
        },
    };

    const NSWindowClass = objc.getClass("NSWindow").?;
    const window_alloc = NSWindowClass.msgSend(Object, "alloc", .{});
    const window = window_alloc.msgSend(Object, "initWithContentRect:styleMask:backing:defer:", .{
        rect,
        @as(ns.UInteger, 15),
        @as(ns.UInteger, 2),
        false,
    });
    window.msgSend(void, "setReleasedWhenClosed:", .{false});

    const title_string = ns.String("poop window");
    window.msgSend(void, "setTitle:", .{title_string});
    window.msgSend(void, "makeKeyAndOrderFront:", .{window});
    window.msgSend(void, "setAcceptsMouseMovedEvents:", .{true});

    const NSObjectClass = objc.getClass("NSObject").?;
    const WidnowDelegateClass = objc.allocateClassPair(NSObjectClass, "WindowDelegate").?;
    std.debug.assert(try WidnowDelegateClass.addMethod("windowWillClose:", windowWillClose));
    const window_delegate = WidnowDelegateClass.msgSend(Object, "alloc", .{}).msgSend(Object, "init", .{});

    window.msgSend(void, "setDelegate:", .{window_delegate});

    // const content_view = window.msgSend(Object, "contentView", .{});

    const NSColorClass = objc.getClass("NSColor").?;
    const red_color = NSColorClass.msgSend(Object, "redColor", .{});
    window.msgSend(void, "setBackgroundColor:", .{red_color});

    app.msgSend(void, "activateIgnoringOtherApps:", .{true});
    const NSDateClass = objc.getClass("NSDate").?;
    const event_mask: ns.UInteger = std.math.maxInt(ns.UInteger);

    // const runloop_mode = ns.String("kCFRunLoopDefaultMode");
    running = true;
    while (running) {
        const distant_past = NSDateClass.msgSend(Object, "distantPast", .{});
        const event = app.msgSend(Object, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
            event_mask,
            distant_past,
            NSDefaultRunLoopMode,
            true,
        });
        if (@intFromPtr(event.value) != 0) {
            app.msgSend(void, "sendEvent:", .{event});
            app.msgSend(void, "updateWindows", .{});
        }

        // rect = content_view.msgSend(ns.Rect, "frame", .{});
    }
}
