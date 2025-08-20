const std = @import("std");
const objc = @import("objc");

const common = @import("common");
const engine = @import("Engine");

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
const GameMemory = engine.GameMemory;
const Renderer = common.Renderer;
const CocoaContext = @import("CocoaContext.zig");

const Application = @This();

const AtomicUsize = std.atomic.Value(usize);
const AtomicBool = std.atomic.Value(bool);

allocator: std.mem.Allocator,

game_code: GameCode,
game_code_loader: ?GameCode.Loader,
game_memory: GameMemory,

time: Time,

pending_resize: bool = false,
running: AtomicBool = AtomicBool.init(false),

mtl_context: MetalContext,
renderer: Renderer,

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

    const game_memory = try engine.GameMemory.init(allocator);
    errdefer game_memory.deinit(allocator);

    game_code.initGameMemory(&game_memory);

    const renderer = try Renderer.init(
        allocator,
        .{
            .max_width = device_info.display_width,
            .max_height = device_info.display_height,
            .width = window_width,
            .height = window_height,
        },
    );
    errdefer renderer.deinit(allocator);

    const mtl_context = MetalContext.init(renderer.framebuffer_pool.backing_memory);
    errdefer mtl_context.deinit();

    const cocoa_context = CocoaContext.init(.{
        .width = window_width,
        .height = window_height,
    }, mtl_context.layer);
    errdefer cocoa_context.deinit();

    log.info("Application initialized", .{});

    return .{
        .allocator = allocator,
        .game_code = game_code,
        .game_code_loader = game_code_loader,
        .game_memory = game_memory,
        .time = time,
        .mtl_context = mtl_context,
        .renderer = renderer,
        .cocoa_context = cocoa_context,
        .device_info = device_info,
    };
}

pub fn deinit(self: *Application) void {
    self.cocoa_context.deinit();
    self.game_code = .stub;
    if (self.game_code_loader) |*loader| {
        loader.deinit(self.allocator);
    }
    self.renderer.deinit(self.allocator);
    self.mtl_context.deinit();
    self.game_memory.deinit(self.allocator);

    log.info("Application deinitialized", .{});
}

pub fn run(self: *Application) !void {
    self.running.store(true, .seq_cst);

    const render_thread = try std.Thread.spawn(.{}, Renderer.renderLoop, .{
        &self.renderer,
        &self.running,
    });
    render_thread.detach();

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

    while (self.running.load(.monotonic)) {
        const render_command_buffer = self.renderer.acquireCommandBuffer() orelse unreachable;
        self.game_code.updateAndRender(
            render_command_buffer,
            &self.game_memory,
            delta_time_s,
        );
        self.renderer.submitCommandBuffer(render_command_buffer);
        timer.wait();
    }
    log.info("game loop exited", .{});
}

const event_timeout_seconds: f64 = 0.001;
fn cocoaLoop(self: *Application) void {
    const mtl_context = &self.mtl_context;
    const framebuffer_pool = &self.renderer.framebuffer_pool;

    while (self.running.load(.monotonic)) {
        self.cocoa_context.processEvents();

        if (framebuffer_pool.acquireReadyBuffer()) |framebuffer| {
            mtl_context.blitAndPresentFramebuffer(&framebuffer);
            framebuffer_pool.releaseBuffer(framebuffer);
        }
        self.updateState();
    }
    log.info("cocoa loop exited", .{});
}

fn updateState(self: *Application) void {
    if (self.cocoa_context.delegate.checkAndClearResized()) {
        const size = self.cocoa_context.windowViewSize();
        self.mtl_context.resizeLayer(size.width, size.height);
        self.renderer.framebuffer_pool.resize(size.width, size.height);
    }
    if (self.cocoa_context.delegate.closed()) {
        self.running.store(false, .seq_cst);
    }
}
