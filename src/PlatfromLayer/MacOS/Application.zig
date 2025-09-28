const std = @import("std");
const common = @import("common");
const engine = @import("Engine");

const MetalContext = @import("MetalContext.zig");
const CocoaContext = @import("CocoaContext.zig");
const HIDContext = @import("HIDContext.zig");
const DeviceInfo = @import("DeviceInfo.zig");
const Time = @import("Time.zig");

const GameCode = common.GameCode;
const GameMemory = engine.GameMemory;
const Renderer = common.Renderer;

const log = std.log.scoped(.platfrom_layer);

const Application = @This();

const AtomicBool = std.atomic.Value(bool);

allocator: std.mem.Allocator,

device_info: DeviceInfo,
renderer: Renderer,

mtl_context: MetalContext,
cocoa_context: CocoaContext,
time: Time,

// input_pool: common.InputPool = .{},

game_memory: GameMemory,

pending_resize: bool = false,
pending_reload: bool = false,
running: AtomicBool = AtomicBool.init(false),

pub fn init(self: *Application, allocator: std.mem.Allocator, window_width: u32, window_height: u32) !void {
    self.* = try initSystems(allocator, window_width, window_height);
    self.initInternalPointers();
}

pub fn initSystems(allocator: std.mem.Allocator, window_width: u32, window_height: u32) !Application {
    // const args = common.Args.get();

    const device_info = DeviceInfo.init();

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

    const time = Time.init();

    const game_memory = try engine.GameMemory.init(allocator);
    errdefer game_memory.deinit(allocator);

    GameCode.initGameMemory(&game_memory);

    log.info("Application initialized", .{});

    return .{
        .allocator = allocator,
        .mtl_context = mtl_context,
        .cocoa_context = cocoa_context,
        .device_info = device_info,
        .time = time,
        .renderer = renderer,
        .game_memory = game_memory,
    };
}

pub fn initInternalPointers(_: *Application) void {}

pub fn deinit(self: *Application) void {
    self.cocoa_context.deinit();
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

    const game_thread = try std.Thread.spawn(.{}, gameLoop, .{
        self,
        @as(f64, 1.0 / 30.0),
    });

    self.cocoaLoop(
        game_thread,
        render_thread,
    );
}

fn gameLoop(self: *Application, time_step_s: f64) void {
    var timer = Time.RepeatingTimer.initAndStart(
        &self.time,
        time_step_s,
    );

    while (self.running.load(.monotonic)) {
        // const input = self.input_pool.acquireReadyInput() orelse &engine.Input{};
        const render_command_buffer = self.renderer.acquireCommandBuffer() orelse continue;
        GameCode.updateAndRender(
            render_command_buffer,
            &self.game_memory,
            // input,
            time_step_s,
        );
        // self.input_pool.releaseInput(input);
        self.renderer.submitCommandBuffer(render_command_buffer);
        timer.wait();
    }

    log.info("game loop exited", .{});
    self.renderer.wake_up.post();
}

const event_timeout_seconds: f64 = 0.001;
fn cocoaLoop(
    self: *Application,
    game_thread: std.Thread,
    render_thread: std.Thread,
) void {
    const mtl_context = &self.mtl_context;
    const framebuffer_pool = &self.renderer.framebuffer_pool;

    while (self.running.load(.monotonic)) {
        // const input = self.input_pool.acquireNextFreeInput();
        self.cocoa_context.processEvents();
        // self.input_pool.releaseInput(input);
        if (framebuffer_pool.acquireReadyBuffer()) |framebuffer| {
            mtl_context.blitAndPresentFramebuffer(&framebuffer);
            framebuffer_pool.releaseBuffer(framebuffer);
        }
        self.updateState();
    }
    log.info("cocoa loop exited", .{});
    game_thread.join();
    render_thread.join();
}
pub var a_key_pressed = false;

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
