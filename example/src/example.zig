const std = @import("std");
const engine = @import("Engine");

const Rect = engine.math.Rect;

const GameState = struct {
    frame: u32 = 0,
    left_paddle: Rect,
    right_paddle: Rect,
};

pub export fn initGameMemory(game_memory: *const engine.GameMemory) void {
    const game_state: *GameState = @ptrCast(@alignCast(game_memory.permanent_storage));
    const paddle_width = 0.1;
    const paddle_height = 0.4;
    game_state.* = .{
        .left_paddle = .{
            .x = -1,
            .y = 0,
            .width = paddle_width,
            .height = paddle_height,
        },

        .right_paddle = .{
            .x = 1,
            .y = 0,
            .width = paddle_width,
            .height = paddle_height,
        },
    };
}

pub export fn updateAndRender(
    render_command_buffer: *engine.RenderCommandBuffer,
    game_memory: *const engine.GameMemory,
    input: *const engine.Input,
    time_step: f64,
) void {
    const game_state: *GameState = @ptrCast(@alignCast(game_memory.permanent_storage));
    // const red: f32 = @as(f32, @floatFromInt(game_state.frame % 255)) / 255.0;
    //
    if (input.keys_state.up) {
        game_state.left_paddle.y -= @as(f32, @floatCast(time_step));
    }
    if (input.keys_state.down) {
        game_state.left_paddle.y += @as(f32, @floatCast(time_step));
    }
    render_command_buffer.push(.{
        .draw_rect = .{
            .rect = game_state.left_paddle,
            .color = .{ 0.0, 0.0, 0.7, 1.0 },
        },
    });

    render_command_buffer.push(.{
        .draw_rect = .{
            .rect = game_state.right_paddle,
            .color = .{ 0.0, 0.0, 0.7, 1.0 },
        },
    });

    game_state.frame += 1;
}
