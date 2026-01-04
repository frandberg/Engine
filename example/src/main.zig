const std = @import("std");
const Engine = @import("Engine");
const Game = @import("Game.zig");

const log = std.log.scoped(.Game);
const DebugAllocator = std.heap.DebugAllocator(.{});
const CommandBuffer = Engine.Graphics.CommandBuffer;
const Application = Engine.LocalWindowdApp;

pub fn main() !void {
    var gpa: DebugAllocator = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try Application.init(allocator, .{
        .update_hz = 85,
        .window = .default,
    });
    defer app.deinit();

    const window_target_handle = app.mainWindowRenderTarget();

    var game = Game.init(allocator, window_target_handle);
    defer game.deinit();

    try app.run(.{
        .update_fn = update,
        .render_fn = render,
    }, &game);
}

fn update(ctx: *anyopaque, time_step_seconds: f64) void {
    const game: *Game = @ptrCast(@alignCast(ctx));
    game.update(time_step_seconds);
}

fn render(ctx: *const anyopaque, command_buffer: CommandBuffer) void {
    const game: *const Game = @ptrCast(@alignCast(ctx));
    game.render(command_buffer);
}
