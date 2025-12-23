const std = @import("std");
const foundation = @import("foundation");
const Platform = @import("platform");

pub const Game = @import("Game.zig");
pub const ecs = @import("ECS/ecs.zig");
pub const Render = @import("Render.zig");
pub const Input = foundation.Input;
pub const math = @import("math");

const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
const Atomic = std.atomic.Value;
const Thread = std.Thread;

const CommandBufferPool = foundation.Render.CommandBufferPool;
const CommandBuffer = foundation.Render.CommandBuffer;

const Engine = @This();

platform: Platform,

arena: Arena,

game: *anyopaque,
game_code: Game.Code,

time_step_seconds: f64,

pub fn init(self: *Engine, gpa: Allocator, game: *anyopaque, config: Game.Config) !void {
    const platform_config: foundation.PlatformInfo = .{
        .window_info = config.window_info,
    };

    self.platform = try .init(
        gpa,
        platform_config,
    );
    errdefer self.platform.deinit();

    self.game_code = config.code;

    self.arena = .init(gpa);
    errdefer self.arena.deinit();

    self.time_step_seconds = 1.0 / config.update_hz;
    self.game = game;
}

pub fn deinit(self: *Engine, _: Allocator) void {
    self.arena.deinit();
    self.platform.deinit();
}

pub fn run(self: *Engine) !void {
    const game_thread: Thread = try .spawn(.{}, gameLoop, .{self});
    defer game_thread.join();

    const render_thread: Thread = try .spawn(.{}, Platform.Renderer.renderLoop, .{ &self.platform.renderer, &Platform.isRunning });
    defer render_thread.join();

    self.platform.mainLoop();
}

fn gameLoop(self: *Engine) void {
    var timer = self.platform.startRepeatingTimer(self.time_step_seconds);

    while (Platform.isRunning()) {
        var cmd_buffer = self.platform.renderer.acquireCommandBuffer();
        defer self.platform.renderer.submitCommandBuffer(cmd_buffer);

        //const input: Input = .fromPacked(self.input.load(.monotonic));

        const render_ctx: Render.Context = .{
            .cmd_buffer = &cmd_buffer,
        };

        self.game_code.update_and_render_fn(
            self.game,
            self.arena.allocator(),
            render_ctx,
            //   input,
            self.time_step_seconds,
        );

        _ = self.arena.reset(.retain_capacity);
        timer.wait();
    }
}
