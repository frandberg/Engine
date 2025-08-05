const std = @import("std");
const objc = @import("objc");
const glue = @import("glue");
const options = @import("options");

const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("mach/mach_time.h");
    @cInclude("pthread.h");
});

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern const NSDefaultRunLoopMode: objc.c.id; // points to @"NSDefaultRunLoopMode"

const Delegate = @import("Delegate.zig");
const GameCode = @import("GameCode.zig");
const MetalContext = @import("MetalContext.zig");
const FramebufferPool = @import("FramebufferPool.zig");
const DeviceInfo = @import("DeviceInfo.zig");
const Time = @import("Time.zig");
const GameMemory = glue.GameMemory;

const Application = @This();

const AtomicUsize = std.atomic.Value(usize);
const AtomicBool = std.atomic.Value(bool);

game_code: GameCode,
lib_paths: GameCode.LibPaths,
game_memory: GameMemory,

time: Time,

mtl_context: MetalContext,
framebuffer_pool: FramebufferPool,
framebuffers_bakcking_mem: []u32,

running: AtomicBool = AtomicBool.init(false),

NSApp: Object,
NSWindow: Object,
delegate: Object,

device_info: DeviceInfo,

pub fn init(app: *Application, allocator: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    app.time = Time.init();

    app.game_memory = try glue.GameMemory.init(allocator);
    errdefer app.game_memory.deinit(allocator);

    app.device_info = DeviceInfo.init();
    app.framebuffers_bakcking_mem = try allocator.alignedAlloc(
        u32,
        std.heap.pageSize(),
        app.device_info.display_width * app.device_info.display_height,
    );
    errdefer allocator.free(app.framebuffers_bakcking_mem);

    app.lib_paths = try GameCode.LibPaths.init(allocator);
    errdefer app.lib_paths.deinit(allocator);

    app.game_code = try GameCode.load(app.lib_paths);
    errdefer app.game_code.unload();
    app.mtl_context = MetalContext.init();

    app.delegate = Delegate.init(&app.running);
    errdefer app.delegate.msgSend(void, "release", .{});

    app.NSApp = objc.getClass("NSApplication").?.msgSend(Object, "sharedApplication", .{});

    app.NSApp.msgSend(void, "setActivationPolicy:", .{@as(usize, 0)}); // NSApplicationActivationPolicyRegular
    app.NSApp.msgSend(void, "setDelegate:", .{app.delegate.value});

    const window_rect = c.CGRectMake(
        0, // x
        0, // y
        @as(c.CGFloat, @floatFromInt(window_width)),
        @as(c.CGFloat, @floatFromInt(window_height)),
    );

    app.NSWindow = objc.getClass("NSWindow").?.msgSend(
        Object,
        "alloc",
        .{},
    ).msgSend(
        Object,
        "initWithContentRect:styleMask:backing:defer:",
        .{
            window_rect,
            @as(usize, 15), // NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable
            @as(usize, 2), // NSBackingStoreBuffered
            false, // d
        },
    );
    errdefer app.NSWindow.msgSend(void, "release", .{});
    app.NSWindow.msgSend(void, "setDelegate:", .{app.delegate.value});
    app.NSWindow.msgSend(void, "makeKeyAndOrderFront:", .{nil});

    app.NSApp.msgSend(void, "finishLaunching", .{});
    app.NSApp.msgSend(void, "activateIgnoringOtherApps:", .{true});

    const view: Object = app.NSWindow.msgSend(Object, "contentView", .{});

    view.msgSend(void, "setWantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{app.mtl_context.layer.value});

    const view_bounds = view.msgSend(c.CGRect, "bounds", .{});

    app.framebuffer_pool = try FramebufferPool.init(
        allocator,
        app.mtl_context.device,
        .{
            .max_width = app.device_info.display_width,
            .max_height = app.device_info.display_height,
            .width = @intFromFloat(view_bounds.size.width),
            .height = @intFromFloat(view_bounds.size.height),
        },
    );
    errdefer app.framebuffer_pool.deinit(allocator);
}

pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
    std.debug.print("deinit Application\n", .{});
    self.delegate.msgSend(void, "release", .{});
    self.NSWindow.msgSend(void, "release", .{});

    self.game_code.unload();
    self.lib_paths.deinit(allocator);

    self.framebuffer_pool.deinit(allocator);
    allocator.free(self.framebuffers_bakcking_mem);
    self.mtl_context.deinit();

    self.game_memory.deinit(allocator);
}

pub fn run(self: *Application) !void {
    self.running.store(true, .seq_cst);

    const game_thread = try std.Thread.spawn(.{}, gameLoop, .{
        // &self.game_code,
        // &self.game_memory,
        // &self.framebuffer_pool,
        // &self.running,
        // &self.time,
        self,
        @as(f64, 1.0 / 60.0),
    });
    game_thread.detach();

    self.cocoaLoop();
}

fn gameLoop(self: *Application, delta_time_s: f64) void {
    var timer = Time.RepeatingTimer.initAndStart(
        &self.time,
        delta_time_s,
    );

    const framebuffer_pool = &self.framebuffer_pool;
    const framebuffers = &framebuffer_pool.framebuffers;
    const game_code = &self.game_code;

    while (self.running.load(.seq_cst)) {
        const framebuffer_index = for (framebuffers, 0..) |framebuffer, i| {
            if (framebuffer.state.load(.seq_cst) == .free) {
                break i;
            }
        } else null;

        if (framebuffer_index) |fb_index| {
            game_code.updateAndRender(
                &framebuffers[fb_index].glueBuffer(),
                &self.game_memory,
                delta_time_s,
            );
            framebuffers[fb_index].state.store(.ready, .seq_cst);
            framebuffer_pool.latest_ready_index.store(@intCast(fb_index), .seq_cst);
        } else {
            game_code.updateAndRender(
                null,
                &self.game_memory,
                delta_time_s,
            );
        }
        timer.wait();
    }
}

const event_timeout_seconds: f64 = 0.001;
fn cocoaLoop(self: *Application) void {
    const framebuffer_pool = &self.framebuffer_pool;
    const mtl_context = &self.mtl_context;

    while (self.running.load(.seq_cst)) {
        if (nextEvent(self.NSApp, event_timeout_seconds)) |event| {
            self.NSApp.msgSend(void, "sendEvent:", .{event});
            self.NSApp.msgSend(void, "updateWindows", .{});
        }
        const frambuffer_index = framebuffer_pool.latest_ready_index.load(.seq_cst);
        if (frambuffer_index == -1) continue;
        const framebuffer = &framebuffer_pool.framebuffers[@intCast(frambuffer_index)];

        if (framebuffer.state.cmpxchgStrong(.ready, .in_use, .seq_cst, .seq_cst)) |old_state| {
            if (old_state == .ready) {
                mtl_context.blitAndPresentFramebuffer(framebuffer_pool, @intCast(frambuffer_index));

                _ = framebuffer_pool.latest_ready_index.cmpxchgStrong(frambuffer_index, -1, .seq_cst, .seq_cst);
            }

            framebuffer.state.store(.free, .seq_cst);
        } else {
            std.debug.print("Failed to change framebuffer state from ready to in_use\n", .{});
        }
    }
    std.debug.print("cocoa loop exited\n", .{});
}

fn nextEvent(app: objc.Object, timeout_seconds: f64) ?objc.c.id {
    const mask = std.math.maxInt(usize);
    const until_date = dateSinceNow(timeout_seconds);
    const event = app.msgSend(objc.c.id, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
        mask,
        until_date,
        NSDefaultRunLoopMode,
        @as(i8, 1),
    });

    if (event != nil) {
        return event;
    } else return null;
}

fn dateSinceNow(seconds: f64) objc.c.id {
    const NSDate = objc.getClass("NSDate").?;
    return NSDate.msgSend(objc.c.id, "dateWithTimeIntervalSinceNow:", .{seconds});
}
