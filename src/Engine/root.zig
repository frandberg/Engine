const std = @import("std");
const foundation = @import("foundation");
const Platform = @import("platform");

pub const Game = @import("Game.zig");
pub const Input = foundation.Input;
pub const RenderCommandBuffer = foundation.Render.CommandBuffer;

const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const Arena = std.heap.ArenaAllocator;
const Atomic = std.atomic.Value;
const Thread = std.Thread;

const CommandBufferPool = foundation.Render.CommandBufferPool;

const Engine = @This();

arena: Arena,
is_running: Atomic(bool),
input: Atomic(Input.Packed),

cmd_buffer_pool: CommandBufferPool,
platform: Platform,

game_memory: Game.Memory,
game_code: Game.Code,
time_step_seconds: f64,

pub fn init(self: *Engine, gpa: Allocator, config: Game.Config) !void {
    const platform_config: foundation.PlatformInfo = .{
        .window_info = config.window_info,
    };

    self.is_running = .init(true);

    self.arena = .init(gpa);
    errdefer self.arena.deinit();

    self.cmd_buffer_pool = try .init(gpa);
    errdefer self.cmd_buffer_pool.deinit(gpa);

    self.platform = try .init(
        gpa,
        platform_config,
        &self.is_running,
        &self.input,
        &self.cmd_buffer_pool,
    );
    errdefer self.platform.deinit();

    self.game_code = config.code;

    const game_permanent_mem = try gpa.alloc(u8, Game.Memory.permanent_storage_size);
    errdefer gpa.free(game_permanent_mem);
    self.game_memory = .{ .permanent = game_permanent_mem };

    self.game_code.init_game_memory_fn(self.game_memory);

    self.time_step_seconds = 1.0 / config.update_hz;
}

pub fn deinit(self: *Engine, gpa: Allocator) void {
    gpa.free(self.game_memory.permanent);
    self.cmd_buffer_pool.deinit(gpa);
    self.platform.deinit();
    self.arena.deinit();
}

pub fn run(self: *Engine) !void {
    const game_thread: Thread = try .spawn(.{}, gameLoop, .{self});
    defer game_thread.join();

    const render_thread: Thread = try .spawn(.{}, Platform.renderLoop, .{&self.platform});
    defer render_thread.join();

    self.platform.mainLoop();
}

fn gameLoop(self: *Engine) void {
    var timer = self.platform.startRepeatingTimer(self.time_step_seconds);

    while (self.is_running.load(.monotonic)) {
        var cmd_buffer = self.cmd_buffer_pool.acquireAvalible() orelse @panic("should not happen\n");
        defer self.cmd_buffer_pool.releaseReady(cmd_buffer);

        const input: Input = .fromPacked(self.input.load(.monotonic));
        self.game_code.update_and_render_fn(
            self.game_memory,
            self.arena.allocator(),
            &cmd_buffer,
            input,
            self.time_step_seconds,
        );

        _ = self.arena.reset(.retain_capacity);
        timer.wait();
    }
}
