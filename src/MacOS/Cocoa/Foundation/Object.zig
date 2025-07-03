const objc = @import("objc");

const String = @import("String.zig");

const wrap = @import("../optionals.zig").wrap;
const unwrap = @import("../optionals.zig").unwrap;

const Self = @This();
object: objc.Object,

pub usingnamespace Extend(Self, "NSObject");
pub fn Extend(comptime T: type, comptime class_name: [:0]const u8) type {
    return struct {
        pub fn alloc() ?T {
            return wrap(T, objc.getClass(class_name).object.msgSend(objc.Object, "alloc", .{}));
        }
        pub fn init(self: T) ?T {
            return wrap(T, self.object.msgSend(objc.Object, "init", .{}));
        }
        pub fn retain(self: T) ?T {
            return wrap(T, self.object.msgSend(objc.Object, "retain", .{}));
        }
        pub fn release(self: T) void {
            self.object.msgSend(void, "release", .{});
        }
        pub fn autorelease(self: T) ?T {
            return wrap(T, self.object.msgSend(objc.Object, "autorelease", .{}));
        }
        pub fn dealloc(self: T) void {
            self.object.msgSend(void, "dealloc", .{});
        }
        pub fn isEqual(self: T, other: T) bool {
            return self.object.msgSend(bool, "isEqual:", .{other.object.value});
        }
        pub fn hash(self: T) usize {
            return self.object.msgSend(usize, "hash", .{});
        }
        pub fn description(self: T) ?String {
            return wrap(String, self.object.msgSend(objc.Object, "description", .{}));
        }
    };
}
