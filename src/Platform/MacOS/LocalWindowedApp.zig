const std = @import("std");
const core = @import("core");

const Cocoa = @import("Cocoa/Cocoa.zig");
const Metal = @import("Metal/Metal.zig");
const Time = @import("Time.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Atomic = std.atomic.Value;
const Thread = std.Thread;
//const Semaphore = std.Thread.Semaphore;
const log = std.log.scoped(.macos_context);

const Graphics = core.Graphics;
const Renderer = core.SofwareRenderer;
const Input = core.Input;
const Game = core.Game.LocalWindowedGame;

const CommandBuffer = Graphics.CommandBuffer;
const FramebufferPool = Renderer.FramebufferPool;
const RepeatingTimer = Time.RepeatingTimer;

const Application = @This();

gpa: Allocator,

spec: core.LocalWindowedAppSpec,

renderer: Renderer,

cocoa_app: Cocoa.Application,

mtl_context: Metal.Context,
main_window_surface: Metal.Surface,

main_window_render_target_handle: Graphics.Target.Handle,

time: Time,

pub fn init(gpa: Allocator, spec: core.LocalWindowedAppSpec) !Application {
    const arena_state: ArenaAllocator = .init(gpa);
    errdefer arena_state.deinit();

    var renderer: Renderer = try .init(gpa);
    errdefer renderer.deinit();

    const main_window_render_target_id = try renderer.createWindowRenderTarget(
        .{
            .width = spec.window.width,
            .height = spec.window.height,
            .format = Graphics.Format.bgra8_u,
            .pixel_origin = .top_left,
        },
    );
    const window_render_target = renderer.render_targets.get(main_window_render_target_id).?.window;

    const cocoa_app: Cocoa.Application = try .init(gpa, spec.window);
    errdefer cocoa_app.deinit();

    const mtl_context: Metal.Context = .init();
    errdefer mtl_context.deinit();

    const mtl_surface: Metal.Surface = .init(mtl_context.device, window_render_target);
    errdefer mtl_surface.deinit();

    cocoa_app.main_window.attachLayer(mtl_surface.layer);

    const time: Time = .init();

    return .{
        .gpa = gpa,
        .spec = spec,
        .renderer = renderer,
        .cocoa_app = cocoa_app,
        .mtl_context = mtl_context,
        .main_window_surface = mtl_surface,
        .main_window_render_target_handle = main_window_render_target_id,
        .time = time,
    };
}

pub fn deinit(self: *Application) void {
    self.main_window_surface.deinit();
    self.mtl_context.deinit();
    self.cocoa_app.deinit();
    self.renderer.deinit();
}

pub fn run(self: *Application, game: Game, game_ctx: *anyopaque) !void {
    const game_thread: Thread = try .spawn(.{}, gameLoop, .{ self, game, game_ctx });
    defer game_thread.join();

    const render_thread: Thread = try .spawn(.{}, Renderer.renderLoop, .{ &self.renderer, Cocoa.Application.isRunning });
    defer render_thread.join();

    self.mainLoop();
}

pub fn mainWindowRenderTarget(self: *const Application) Graphics.Target.Handle {
    return self.main_window_render_target_handle;
}

fn gameLoop(self: *Application, game: Game, game_ctx: *anyopaque) void {
    const time_step_seconds = 1.0 / self.spec.update_hz;
    var timer: RepeatingTimer = .start(self.time, time_step_seconds);

    while (Cocoa.Application.isRunning()) {
        game.update_fn(game_ctx, time_step_seconds);

        var cmd_buffer: Renderer.CommandBuffer = self.renderer.acquireCommandBuffer();
        game.render_fn(
            game_ctx,
            cmd_buffer.cmdBuffer(),
        );
        self.renderer.submitCommandBuffer(cmd_buffer);

        timer.wait();
    }
    log.info("Game loop exited", .{});
}

fn mainLoop(self: *Application) void {
    while (Cocoa.Application.isRunning()) {
        self.cocoa_app.pollEvents() catch @panic("failed to poll events");

        const framebuffer_pool = self.mainWindowFramebufferPool();
        self.main_window_surface.present(self.mtl_context, framebuffer_pool);

        self.updateState();
    }
    self.renderer.wake_up.post();
    log.info("Main loop exited", .{});
}

fn mainWindowFramebufferPool(self: *const Application) *FramebufferPool {
    return &self.renderer.render_targets.getPtr(self.main_window_render_target_handle).?.window;
}

fn updateState(self: *Application) void {
    const framebuffer_pool = self.mainWindowFramebufferPool();
    if (self.main_window_surface.needsResize()) |size| {
        //log.debug("Resizing main window surface to {d}x{d}", .{ size.width, size.height });
        switch (framebuffer_pool.resizeState()) {
            .idle => {
                framebuffer_pool.requestResize(size.width, size.height);
            },
            .applied => {
                self.main_window_surface.recreate(
                    self.mtl_context.device,
                    framebuffer_pool.*,
                );
                framebuffer_pool.resize_state.store(.idle, .release);
            },
            .requested => {},
        }
    }
}
