const std = @import("std");
const objc = @import("objc");
const glue = @import("glue");
const options = @import("options");

const common = @import("common");

const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("mach/mach_time.h");
    @cInclude("pthread.h");
});

const log = std.log.scoped(.platfrom_layer);

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern const NSDefaultRunLoopMode: objc.c.id;

const GameCode = @import("GameCode.zig");
const MetalContext = @import("MetalContext.zig");
const DeviceInfo = @import("DeviceInfo.zig");
const Time = @import("Time.zig");
const GameMemory = glue.GameMemory;
const FramebufferPool = common.FramebufferPool;
const CocoaContext = @import("CocoaContext.zig");

const Application = @This();

const AtomicUsize = std.atomic.Value(usize);
const AtomicBool = std.atomic.Value(bool);

game_code: GameCode,
game_code_loader: ?GameCode.Loader,
game_memory: GameMemory,

time: Time,

pending_resize: bool = false,
running: AtomicBool = AtomicBool.init(false),

mtl_context: MetalContext,
framebuffer_pool: FramebufferPool,

cocoa_context: CocoaContext,
device_info: DeviceInfo,

pub fn init(allocator: std.mem.Allocator, window_width: u32, window_height: u32) !Application {
    const args = common.Args.get();
    const time = Time.init();

    const device_info = DeviceInfo.init();

    var game_code_loader = if (args.game_lib) |game_lib|
        try GameCode.Loader.init(
            allocator,
            game_lib,
            args.hot_reload,
        )
    else
        null;

    errdefer {
        if (game_code_loader) |*loader| {
            loader.deinit(allocator);
        }
    }

    const game_code = if (game_code_loader) |*loader|
        try loader.load()
    else
        GameCode.stub;

    const game_memory = try glue.GameMemory.init(allocator);
    errdefer game_memory.deinit(allocator);

    game_code.initGameMemory(&game_memory);

    const framebuffer_pool = try FramebufferPool.init(
        allocator,
        .{
            .buffer_count = 3,
            .max_width = device_info.display_width,
            .max_height = device_info.display_height,
            .width = window_width,
            .height = window_height,
        },
    );
    errdefer framebuffer_pool.deinit(allocator);

    const mtl_context = MetalContext.init(framebuffer_pool.backing_memory);
    errdefer mtl_context.deinit();

    const cocoa_context = CocoaContext.init(.{
        .width = window_width,
        .height = window_height,
    }, mtl_context.layer);
    errdefer cocoa_context.deinit();

    std.log.info("Application initialized", .{});

    return .{
        .game_code = game_code,
        .game_code_loader = game_code_loader,
        .game_memory = game_memory,
        .time = time,
        .mtl_context = mtl_context,
        .framebuffer_pool = framebuffer_pool,
        .cocoa_context = cocoa_context,
        .device_info = device_info,
    };
}

pub fn deinit(self: *Application, allocator: std.mem.Allocator) void {
    self.cocoa_context.deinit();
    self.game_code = .stub;
    if (self.game_code_loader) |*loader| {
        loader.deinit(allocator);
    }
    self.framebuffer_pool.deinit(allocator);
    self.mtl_context.deinit();
    self.game_memory.deinit(allocator);

    std.log.info("Application deinitialized\n", .{});
}

pub fn run(self: *Application) !void {
    self.running.store(true, .seq_cst);

    const game_thread = try std.Thread.spawn(.{}, gameLoop, .{
        self,
        @as(f64, 1.0 / 30.0),
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

    while (self.running.load(.seq_cst)) {
        if (framebuffer_pool.acquireNextFreeBuffer()) |framebuffer| {
            framebuffer.clear(0);
            self.game_code.updateAndRender(
                &framebuffer.glueBuffer(),
                &self.game_memory,
                delta_time_s,
            );

            framebuffer_pool.releaseBufferAndMakeReady(&framebuffer);
        } else {
            self.game_code.updateAndRender(
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
        self.cocoa_context.processEvents();
        if (self.framebuffer_pool.acquireReadyBuffer()) |framebuffer| {
            mtl_context.blitAndPresentFramebuffer(&framebuffer);
            framebuffer_pool.releaseBuffer(&framebuffer);
        }
        self.updateState();
    }
    log.debug("cocoa loop exited\n", .{});
}

fn updateState(self: *Application) void {
    if (self.cocoa_context.delegate.checkAndClearResized()) {
        const size = self.cocoa_context.windowViewSize();
        self.mtl_context.resizeLayer(size.width, size.height);
        self.framebuffer_pool.resize(size.width, size.height);
    }
    if (self.cocoa_context.delegate.closed()) {
        log.debug("Window closed\n", .{});
        self.running.store(false, .seq_cst);
    }
}
