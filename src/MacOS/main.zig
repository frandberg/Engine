const std = @import("std");
const objc = @import("objc");
const Delegate = @import("Delegate.zig");
const glue = @import("glue");
const ns = @import("Cocoa.zig");

const Object = objc.Object;

const GameCode = @import("GameCode.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    var lib_path: ?[]const u8 = null;
    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-lib")) {
            lib_path = args[i + 1];
            break;
        }
    }
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);

    std.debug.print("exe path: {s}\nlib_path: {?s}\n", .{ exe_path, lib_path });

    // const NSApplication = objc.getClass("NSApplication").?;

    const app = ns.App.get();

    const window = ns.Window.init(
        "poop 420",
        800,
        600,
        100,
        100,
        .{
            .closable = 1,
            .titled = 1,
            .miniaturizable = 1,
            .resizable = 1,
        },
    );

    window.makeKeyandOrderFront();

    app.activate();

    var running = true;
    var game_code = try GameCode.load(allocator, lib_path.?);
    while (running) {
        if (try GameCode.getLastChangedTime(game_code.lib_path) != game_code.last_change_time) {
            game_code.unload();
            game_code = try GameCode.load(allocator, lib_path.?);
        }
        while (app.getNextEvent()) |event| {
            switch (event) {
                .key_down => |key_code| {
                    if (key_code == .escape) {
                        running = false;
                    } else {
                        std.debug.print("{s}\n", .{@tagName(key_code)});
                    }
                },
                else => {},
            }
        }
        app.updateWindows();
        game_code.update_and_render_fn();
    }
}
