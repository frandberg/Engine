const std = @import("std");
const engine = @import("Engine");

const Rect = engine.math.Rect;

const GameState = struct {
    frame: u32 = 0,
    rects: [2]Rect,
};

pub export fn initGameMemory(game_memory: *const engine.GameMemory) callconv(.c) void {
    const game_state: *GameState = @alignCast(@ptrCast(game_memory.permanent_storage));
    game_state.* = .{
        .rects = .{
            .{
                .x = 0.05 - 1.0,
                .y = 0.0,
                .width = 0.1,
                .height = 0.5,
            },
            .{
                .x = 1 - 0.05,
                .y = 0.0,
                .width = 0.1,
                .height = 0.5,
            },
        },
    };
}

pub export fn updateAndRender(
    render_command_buffer: *engine.RenderCommandBuffer,
    game_memory: *const engine.GameMemory,
) void {
    const game_state: *GameState = @alignCast(@ptrCast(game_memory.permanent_storage));
    // const red: f32 = @as(f32, @floatFromInt(game_state.frame % 255)) / 255.0;
    //
    for (&game_state.rects) |rect|
        render_command_buffer.appendCommand(.{
            .draw_rect = .{
                .rect = rect,
                .color = .{ 0.6, 0.0, 0.7, 1.0 },
            },
        }) catch @panic("Failed to record draw command");

    game_state.frame += 1;
}
