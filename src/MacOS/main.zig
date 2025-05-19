const std = @import("std");
const objc = @import("objc");
const AppDelegate = @import("Delegate.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    const lib_path: ?[]const u8 = blk: for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-lib")) {
            break :blk args[i + 1];
        }
    } else null;

    const dll = if (lib_path) |path| try std.DynLib.open(path) else null;
    if (dll) |_| {
        std.debug.print("loaded dll\n", .{});
    }

    const NSApplication: objc.Class = objc.getClass("NSApplication").?;
    const app: objc.Object = NSApplication.msgSend(objc.Object, "sharedApplication", .{});
    const delegate = try AppDelegate.createDelegate();

    app.msgSend(void, "setDelegate:", .{delegate});

    app.msgSend(void, "run", .{});
}
