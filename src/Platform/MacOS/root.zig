const std = @import("std");
const foundation = @import("foundation");
const MetalContext = @import("MetalContext.zig");
const CocoaContext = @import("CocoaContext.zig");
const Time = @import("Time.zig");

const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Value;
const log = std.log.scoped(.macos_context);
const PlatformInfo = foundation.PlatformInfo;
const Renderer = foundation.SofwareRenderer;
const Render = foundation.Render;
const CommandBuffer = Render.CommandBuffer;
const FramebufferPool = Renderer.FramebufferPool;
const Input = foundation.Input;

const RepeatingTimer = Time.RepeatingTimer;

const MacOSContext = @This();

allocator: Allocator,
cocoa_context: CocoaContext,
mtl_context: MetalContext,
renderer: Renderer,
time: Time,

is_running: *Atomic(bool),
input: *Atomic(Input.Packed),

pub fn init(
    gpa: Allocator,
    info: PlatformInfo,
    is_running: *Atomic(bool),
    input: *Atomic(Input.Packed),
    cmd_buffer_pool: *Render.CommandBufferPool,
) !MacOSContext {
    const width = info.window_info.width;
    const height = info.window_info.height;

    var renderer: Renderer = try .init(gpa, cmd_buffer_pool, is_running, width, height);
    errdefer renderer.deinit(gpa);

    const mtl_context: MetalContext = .init(renderer.framebuffer_pool.backing_memory);
    errdefer mtl_context.deinit();

    const cocoa_context: CocoaContext = .init(
        .{ .width = width, .height = height },
        mtl_context.layer,
    );
    errdefer cocoa_context.deinit();

    const time = Time.init();

    return .{
        .allocator = gpa,
        .cocoa_context = cocoa_context,
        .mtl_context = mtl_context,
        .renderer = renderer,
        .time = time,
        .is_running = is_running,
        .input = input,
    };
}

pub fn deinit(self: *MacOSContext) void {
    self.renderer.deinit(self.allocator);
    self.cocoa_context.deinit();
    self.mtl_context.deinit();
}

pub fn mainLoop(self: *MacOSContext) void {
    const mtl_context = &self.mtl_context;
    const framebuffer_pool = &self.renderer.framebuffer_pool;

    while (self.is_running.load(.monotonic)) {
        const new_input: Input = self.cocoa_context.processInput(.fromPacked(self.input.load(.seq_cst)));
        self.input.store(Input.toPacked(new_input), .seq_cst);
        if (framebuffer_pool.acquireReady()) |framebuffer| {
            mtl_context.blitAndPresentFramebuffer(&framebuffer);
            framebuffer_pool.release(framebuffer);
        }

        self.updateState();
    }

    self.renderer.wake_up.post();
    log.info("cocoa loop exited", .{});
}

pub fn renderLoop(self: *MacOSContext) void {
    self.renderer.renderLoop();
}

pub fn startRepeatingTimer(self: *const MacOSContext, time_step_seconds: f64) RepeatingTimer {
    return Time.RepeatingTimer.start(&self.time, time_step_seconds);
}

fn updateState(self: *MacOSContext) void {
    if (self.cocoa_context.delegate.checkAndClearResized()) {
        const size = self.cocoa_context.windowViewSize();
        self.renderer.framebuffer_pool.requestResize(size.width, size.height);
    }
    if (self.renderer.resizeState() == .applied) {
        self.mtl_context.resize(
            self.renderer.framebuffer_pool.backing_memory,
            self.renderer.framebuffer_pool.width,
            self.renderer.framebuffer_pool.height,
        );
        self.renderer.setResizeState(.idle);
    }
    if (self.cocoa_context.delegate.closed()) {
        self.is_running.store(false, .seq_cst);
    }
}
