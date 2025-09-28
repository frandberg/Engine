const std = @import("std");
const engine = @import("Engine");

const log = std.log.scoped(.game_code);

pub extern fn initGameMemory(game_memory: *const engine.GameMemory) void;
pub extern fn updateAndRender(
    render_command_buffer: *engine.RenderCommandBuffer,
    game_memory: *const engine.GameMemory,
    // input: *const engine.Input,
    time_step_s: f64,
) void;
