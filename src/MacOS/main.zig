const std = @import("std");
const objc = @import("objc");
const Delegate = @import("Delegate.zig");
const glue = @import("glue");

const GameCode = struct {};

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    const lib_path: ?[]const u8 = blk: for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-lib")) {
            break :blk args[i + 1];
        }
    } else null;
    const delegate = try Delegate.init(lib_path);

    const NSApplication: objc.Class = objc.getClass("NSApplication").?;
    const app = NSApplication.msgSend(objc.Object, "sharedApplication", .{});
    app.msgSend(void, "setDelegate:", .{delegate.obj});
    app.msgSend(void, "run", .{});
}
