const std = @import("std");
const objc = @import("objc");
const ns = @import("Cocoa");
const cg = @import("CoreGraphics");
const GameCode = @import("GameCode.zig");

const glue = @import("glue");

const c = @cImport({
    @cInclude("mach/mach_time.h");
});

const Object = objc.Object;
const Id = objc.c.id;

var sem: std.Thread.Semaphore = .{};

const window_width = 800;
const window_height = 600;

extern const NSApp: Id;

// const MacOSOffscreenBuffer = struct {
//     memory: []u8,
//     width: u32,
//     height: u32,
//
//     pub fn init(allocator: std.mem.Allocator, device: Object, width: u32, height: u32) !MacOSOffscreenBuffer {
//         const size = width * height * glue.OffscreenBuffer.bytes_per_pixel;
//         const memory = try allocator.alloc(u8, size);
//         const texture = mtl.Texture.create(device, width, height);
//         return .{
//             .memory = memory,
//             .width = width,
//             .height = height,
//             .texture = texture,
//         };
//     }
//     pub fn glueBuffer(self: MacOSOffscreenBuffer) glue.OffscreenBuffer {
//         return .{
//             .memory = self.memory,
//             .widht = self.width,
//             .height = self.height,
//         };
//     }
// };

pub fn main() !void {
    var running: bool = false;

    var args_iter = std.process.args();
    _ = c.mach_absolute_time();

    var maybe_lib_path: ?[]const u8 = null;
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, "--game-lib", arg)) {
            maybe_lib_path = args_iter.next();
        }
    }
    const lib_path = maybe_lib_path orelse return error.LibNotFound;

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var game_code = try GameCode.load(allocator, lib_path);

    const app = ns.Application.sharedApplication();

    const origin = cg.Point{
        .x = 0,
        .y = 0,
    };

    const size = cg.Size{
        .width = window_width,
        .height = window_height,
    };
    const rect: ns.Rect = .{
        .origin = origin,
        .size = size,
    };

    const window = ns.Window.alloc().@"initWithContentRect:styleMask:backing:defer"(
        rect,
        .{ .titled = true, .closable = true, .resizable = true },
        .retained,
        false,
    );

    // const buffer = try MacOSOffscreenBuffer.init(
    //     allocator,
    //     mtl_context.device,
    //     window_width,
    //     window_height,
    // );
    //
    window.@"makeKeyAndOrderFront:"(.{ .value = @as(objc.c.id, @ptrFromInt(0)) });

    app.@"setActivationPolicy:"(.regular);
    app.@"activateIgnoringOtherApps:"(true);

    const NSAutoreleasePoolClass = objc.getClass("NSAutoreleasePool").?;

    const time_step: i64 = 1_000_000_000 / 30;
    const max_frame_count = 10;
    var frame_index: usize = 0;

    const distant_past = ns.Date.distantPast();

    running = true;
    while (running) {
        const frame_start_time = std.time.nanoTimestamp();
        const autorelease_pool = NSAutoreleasePoolClass.msgSend(Object, "alloc", .{}).msgSend(
            Object,
            "init",
            .{},
        );
        defer _ = autorelease_pool.msgSend(Object, "drain", .{});
        while (app.@"nextEventMatchingMask:untilDate:inMode:dequeue:"(
            .any,
            distant_past,
            ns.DefaultRunLoopMode(),
            true,
        )) |event| {
            app.@"sendEvent:"(event);
            app.updateWindows();
        }
        //
        const frame_time: i128 = std.time.nanoTimestamp() - frame_start_time;
        //
        std.debug.print("frame {}: {}us\n", .{ frame_index, @divFloor(frame_time, 1000) });

        const sleep_time: i128 = time_step - @as(i64, @intCast(frame_time));
        if (sleep_time >= 0) {
            std.Thread.sleep(@intCast(sleep_time));
        }

        frame_index += 1;
        if (frame_index == max_frame_count) {
            running = false;
        }
    }
    try game_code.unload();
}
