const std = @import("std");
const objc = @import("objc");
const glue = @import("glue");

const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("mach/mach_time.h");
});

const Object = objc.Object;
const nil = objc.c.id(@ptrFromInt(0));

extern const NSDefaultRunLoopMode: objc.c.id;

const framebuffer_count: usize = 2;

const GameCode = @import("GameCode.zig");
const MetalContext = @import("MetalContext.zig");
const FramebufferPool = @import("FramebufferPool.zig");
const DeviceInfo = @import("DeviceInfo.zig");
const GameMemory = glue.GameMemory;

const Application = @This();

const AtomicUsize = std.atomic.Value(usize);
const AtomicBool = std.atomic.Value(bool);

game_code: GameCode,
game_memory: GameMemory,

mtl_context: MetalContext,
framebuffer_pool: FramebufferPool,
framebuffers_bakcking_mem: []u32,
latest_framebuffer_index: AtomicUsize,

running: AtomicBool = false,

NSApp: Object,
NSWindow: Object,
delegate: Object,

device_info: DeviceInfo,

pub fn init(app: *Application, allocator: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    const game_memory_permanent = try allocator.alignedAlloc(u8, std.heap.pageSize(), glue.GameMemory.permanent_storage_size);
    errdefer allocator.free(game_memory_permanent);
    const game_memory_transient = try allocator.alignedAlloc(u8, std.heap.pageSize(), glue.GameMemory.transient_storage_size);
    errdefer allocator.free(game_memory_transient);

    app.game_memory = .{
        .permanent_storage = game_memory_permanent.ptr,
        .transient_storage = game_memory_transient.ptr,
    };

    app.device_info = DeviceInfo.init();
    app.framebuffers_bakcking_mem = try allocator.alignedAlloc(u32, std.heap.pageSize(), DeviceInfo.display_width * DeviceInfo.display_height);
    errdefer allocator.free(app.framebuffers_bakcking_mem);

    app.game_code = try GameCode.load(allocator);
    errdefer app.game_code.unload();

    app.mtl_context = MetalContext.init();

    app.framebuffer_pool = try FramebufferPool.init(
        app.mtl_context.device,
        app.framebuffers_bakcking_mem,
        window_width,
        window_height,
    );
    errdefer app.framebuffer_pool.deinit();

    app.delegate = Application.Delegate.init(&app.running);
    errdefer app.delegate.msgSend(void, "release", .{});

    app.NSApp = objc.getClass("NSApplication").?.msgSend(Object, "sharedApplication", .{});
    errdefer app.NSApp.msgSend(void, "release", .{});

    app.NSApp.msgSend(void, "setActivationPolicy:", .{@as(usize, 0)}); // NSApplicationActivationPolicyRegular
    app.NSApp.msgSend(void, "setDelegate:", .{app.delegate.value});
    defer {}

    const window_rect = c.CGRectMake(
        0, // x
        0, // y
        @as(c.CGFloat, window_width), // width
        @as(c.CGFloat, window_height), // height
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
    app.NSWindow.msgSend(void, "makeKeyAndOrderFront:", nil);

    app.msgSend(void, "finishLaunching", .{});
    app.msgSend(void, "activate", .{});

    const view: Object = app.NSwindow.msgSend(Object, "contentView", .{});

    view.msgSend(void, "setWantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{app.mtl_context.layer.value});
}
pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
    self.game_code.unload();

    self.delegate.msgSend(void, "release", .{});
    self.NSWindow.msgSend(void, "release", .{});
    self.NSApp.msgSend(void, "release", .{});

    self.framebuffer_pool.deinit();
    self.mtl_context.deinit();

    allocator.free(self.game_memory.permanent_storage);
    allocator.free(self.game_memory.transient_storage);
    allocator.free(self.framebuffers_bakcking_mem);
}
pub fn run(self: *Application) void {
    self.running = true;

    const game_thread = try std.Thread.spawn(.{}, gameLoop, .{self});
    defer game_thread.join();
    self.cocoaLoop();
}

const delta_time_s: f64 = 1.0 / 60.0;

fn gameLoop(self: *Application) void {
    _ = self;
}

const event_timeout_seconds: f64 = 0.0005;
fn cocoaLoop(self: *Application) void {
    while (self.running.load(.seq_cst)) {
        if (nextEvent(self.NSApp, event_timeout_seconds)) |event| {
            self.app.msgSend(void, "sendEvent:", .{event});
            self.app.msgSend(void, "updateWindows", .{});
        }
        const i = self.latest_framebuffer_index.load(.seq_cst);
        if (self.framebuffer_pool.stateCmpAndSwap(i, .ready, .in_use)) {
            self.mtl_context.blitAndPresentFramebuffer(&self.framebuffer_pool, i);
            self.framebuffer_pool.setBufferState(i, .free);
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
        true,
    });

    if (event != nil) {
        return event;
    } else return null;
}

fn dateSinceNow(seconds: f64) objc.c.id {
    const NSDate = objc.getClass("NSDate").?;
    return NSDate.msgSend(objc.c.id, "dateWithTimeIntervalSinceNow:", .{seconds});
}
