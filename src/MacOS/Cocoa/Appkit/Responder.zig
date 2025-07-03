const objc = @import("objc");

const Event = @import("Event.zig");
const Menu = @import("Menu.zig");
const foundation = @import("../Foundation/Foundation.zig");

const Object = foundation.Object;
const String = foundation.String;

const wrap = @import("../optionals.zig").wrap;

pub fn Extend(comptime T: type, comptime class_name: []const u8) type {
    return struct {
        pub usingnamespace Object.Extend(T, class_name);

        pub fn nextResponder(self: T) ?T {
            return wrap(T, self.object.msgSend(objc.Object, "nextResponder", .{}));
        }
        pub fn becomeFirstResponder(self: T) bool {
            return self.object.msgSend(bool, "becomeFirstResponder", .{});
        }
        pub fn resignFirstResponder(self: T) bool {
            return self.object.msgSend(bool, "resignFirstResponder", .{});
        }
        pub fn acceptsFirstResponder(self: T) bool {
            return self.object.msgSend(bool, "acceptsFirstResponder", .{});
        }
        pub fn mouseDown(self: T, event: Event) void {
            self.object.msgSend(void, "mouseDown:", .{event.object.value});
        }
        pub fn mouseUp(self: T, event: Event) void {
            self.object.msgSend(void, "mouseUp:", .{event.object.value});
        }
        pub fn mouseMoved(self: T, event: Event) void {
            self.object.msgSend(void, "mouseMoved:", .{event.object.value});
        }
        pub fn mouseDragged(self: T, event: Event) void {
            self.object.msgSend(void, "mouseDragged:", .{event.object.value});
        }
        pub fn rightMouseDown(self: T, event: Event) void {
            self.object.msgSend(void, "rightMouseDown:", .{event.object.value});
        }
        pub fn rightMouseUp(self: T, event: Event) void {
            self.object.msgSend(void, "rightMouseUp:", .{event.object.value});
        }
        pub fn rightMouseDragged(self: T, event: Event) void {
            self.object.msgSend(void, "rightMouseDragged:", .{event.object.value});
        }
        pub fn otherMouseDown(self: T, event: Event) void {
            self.object.msgSend(void, "otherMouseDown:", .{event.object.value});
        }
        pub fn otherMouseUp(self: T, event: Event) void {
            self.object.msgSend(void, "otherMouseUp:", .{event.object.value});
        }
        pub fn otherMouseDragged(self: T, event: Event) void {
            self.object.msgSend(void, "otherMouseDragged:", .{event.object.value});
        }
        pub fn keyDown(self: T, event: Event) void {
            self.object.msgSend(void, "keyDown:", .{event.object.value});
        }
        pub fn keyUp(self: T, event: Event) void {
            self.object.msgSend(void, "keyUp:", .{event.object.value});
        }
        pub fn flagsChanged(self: T, event: Event) void {
            self.object.msgSend(void, "flagsChanged:", .{event.object.value});
        }
        pub fn performMnemonic(self: T, mnemonic: String) bool {
            return self.object.msgSend(bool, "performMnemonic:", .{mnemonic.object.value});
        }
        pub fn flushBufferedKeyEvents(self: T) void {
            self.object.msgSend(void, "flushBufferedKeyEvents", .{});
        }
        pub fn performKeyEquivalent(self: T, event: Event) bool {
            return self.object.msgSend(bool, "performKeyEquivalent:", .{event.object.value});
        }

        pub fn pressureChangeWithEvent(self: T, event: Event) void {
            self.object.msgSend(void, "pressureChangeWithEvent:", .{event});
        }

        pub fn cursorUpdate(self: T, event: Event) void {
            self.object.msgSend(void, "cursorUpdate:", .{event});
        }

        pub fn tabletPoint(self: T, event: Event) void {
            self.object.msgSend(void, "tabletPoint:", .{event});
        }
        pub fn tabletProximity(self: T, event: Event) void {
            self.object.msgSend(void, "tabletProximity:", .{event});
        }
        pub fn helpRequested(self: T, event: Event) void {
            self.object.msgSend(void, "helpRequested:", .{event.object.value});
        }
        pub fn scrollWheel(self: T, event: Event) void {
            self.object.msgSend(void, "scrollWheel:", .{event});
        }
        pub fn quickLookWithEvent(self: T, event: Event) void {
            self.object.msgSend(void, "quickLookWithEvent:", .{event});
        }
        pub fn changeModeWithEvent(self: T, event: Event) void {
            self.object.msgSend(void, "changeModeWithEvent:", .{event});
        }

        pub fn menu(self: T) ?Menu {
            return wrap(Menu, self.object.msgSend(objc.Object, "menu", .{}));
        }

        pub fn setMenu(self: T, menu_: Menu) void {
            self.object.msgSend(void, "setMenu:", .{menu_.object.value});
        }

        pub fn interfaceStyle(self: T) ?String {
            return wrap(String, self.object.msgSend(objc.Object, "interfaceStyle", .{}));
        }

        pub fn setInterfaceStyle(self: T, style: String) void {
            self.object.msgSend(void, "setInterfaceStyle:", .{style.object.value});
        }

        pub fn userActivity(self: T) ?Object {
            return wrap(Object, self.object.msgSend(objc.Object, "userActivity", .{}));
        }
        pub fn setUserActivity(self: T, activity: objc.Object) void {
            self.object.msgSend(void, "setUserActivity:", .{activity.value});
        }
    };
}
