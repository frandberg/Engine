const std = @import("std");
const foundation = @import("foundation");
const MetalContext = @import("MetalContext.zig");
const CocoaContext = @import("CocoaContext.zig");
const Time = @import("Time.zig");

const Allocator = std.mem.Allocator;
const Atomic = std.atomic.Value;
const Semaphore = std.Thread.Semaphore;
const log = std.log.scoped(.macos_context);
const PlatformInfo = foundation.PlatformInfo;
const Render = foundation.Render;
const CommandBuffer = Render.CommandBuffer;
const FramebufferPool = Renderer.FramebufferPool;
const Input = foundation.Input;

const RepeatingTimer = Time.RepeatingTimer;

pub const Renderer = foundation.SofwareRenderer;

const MacOS = @This();

//common to all platforms
allocator: Allocator,
renderer: Renderer,

//Mac os specific
cocoa_context: CocoaContext,
mtl_context: MetalContext,
time: Time,

pub fn init(
    gpa: Allocator,
    info: PlatformInfo,
) !MacOS {
    const width = info.window_info.width;
    const height = info.window_info.height;

    var renderer: Renderer = try .init(
        gpa,
        width,
        height,
    );
    errdefer renderer.deinit(gpa);

    const cocoa_context: CocoaContext = .init(width, height);
    errdefer cocoa_context.deinit();

    const mtl_context: MetalContext = .init(renderer.framebuffer_pool.backing_memory, cocoa_context.view());
    errdefer mtl_context.deinit();
    const time = Time.init();

    return .{
        .allocator = gpa,
        .cocoa_context = cocoa_context,
        .mtl_context = mtl_context,
        .renderer = renderer,
        .time = time,
    };
}

pub fn deinit(self: *MacOS) void {
    self.renderer.deinit(self.allocator);
    self.cocoa_context.deinit();
    self.mtl_context.deinit();
}

pub fn mainLoop(self: *MacOS) void {
    const mtl_context = &self.mtl_context;
    const framebuffer_pool = &self.renderer.framebuffer_pool;

    while (isRunning()) {
        const prev_input = Input{};
        _ = self.cocoa_context.processInput(prev_input);
        if (framebuffer_pool.consume()) |framebuffer| {
            mtl_context.blitAndPresentFramebuffer(&framebuffer);
            framebuffer_pool.release(framebuffer);
        }

        self.updateState();
    }

    self.renderer.wake_up.post();
    log.info("cocoa loop exited", .{});
}

pub fn startRepeatingTimer(self: *const MacOS, time_step_seconds: f64) RepeatingTimer {
    return Time.RepeatingTimer.start(&self.time, time_step_seconds);
}

pub fn isRunning() bool {
    return CocoaContext.isRunning();
}

fn updateState(self: *MacOS) void {
    if (self.mtl_context.need_resize) |new_size| {
        self.renderer.requestResize(new_size.width, new_size.height);
        self.mtl_context.need_resize = null;
    }
    if (self.renderer.resizeState() == .applied) {
        self.mtl_context.recreateFramebuffers(
            self.renderer.framebuffer_pool.backing_memory,
            self.renderer.framebuffer_pool.width,
            self.renderer.framebuffer_pool.height,
        );
        self.renderer.setResizeState(.idle);
    }
}
