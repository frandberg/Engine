const objc = @import("objc");

const Menu = @import("Menu.zig");
const Event = @import("Event.zig");

const foundation = @import("../Foundation/Foundation.zig");
const Responder = @import("Responder.zig");
const Date = foundation.Date;
const String = foundation.String;

const wrap = @import("../optionals.zig").wrap;

const UInteger = foundation.UInteger;
const Integer = foundation.Integer;

const class_name = "NSApplication";
const Self = @This();

object: objc.Object,

pub usingnamespace Responder.Extend(Self, class_name);
pub fn sharedApplication() Self {
    return wrap(Self, objc.getClass(class_name).?.msgSend(objc.Object, "sharedApplication", .{}));
}

pub fn setMainMenu(self: Self, menu: Menu) void {
    self.object.msgSend(void, "setMainMenu:", .{menu.object.id});
}
pub fn setActivationPolicy(self: Self, policy: ActivationPolicy) void {
    self.object.msgSend(void, "setActivationPolicy:", .{@as(Integer, @intFromEnum(policy))});
}

pub fn activateIgnoringOtherApps(self: Self, ignoreOtherApps: bool) void {
    self.object.msgSend(void, "activateIgnoringOtherApps:", .{ignoreOtherApps});
}

pub fn finishLaunching(self: Self) void {
    self.object.msgSend(void, "finishLaunching", .{});
}

pub fn setDelegate(self: Self, delegate: objc.Object) void {
    self.object.msgSend(void, "setDelegate:", .{delegate.value});
}

pub fn sendEvent(self: Self, event: Event) void {
    self.object.msgSend(void, "sendEvent:", .{event.object.value});
}

pub fn updateWindows(self: Self) void {
    self.object.msgSend(void, "updateWindows", .{});
}

pub fn @"nextEventMatchingMask:untilDate:inMode:dequeue:"(
    self: Self,
    mask: Event.Mask,
    untilDate: Date,
    mode: String,
    dequeue: bool,
) ?Event {
    return wrap(Event, self.object.msgSend(objc.Object, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
        mask,
        untilDate.object.value,
        mode.object.value,
        dequeue,
    }));
}

pub const ActivationPolicy = enum(Integer) {
    regular = 0, // NSSelfActivationPolicyRegular
    accessory = 1, // NSSelfActivationPolicyAccessory
    proHidden = 2, // NSSelfActivationPolicyProhibited
    _,
};
