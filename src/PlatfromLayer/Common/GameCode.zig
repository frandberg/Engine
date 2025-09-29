const std = @import("std");
const engine = @import("Engine");

const log = std.log.scoped(.game_code);
const GameCode = @This();

pub extern fn initGameMemory(game_memory: *engine.GameMemory) void;

pub extern fn updateAndRender(render_command_buffer: *engine.RenderCommandBuffer, game_memory: *const engine.GameMemory, time_step_s: f64) void;

// init_game_memory_fn: *const fn (game_memory: *const engine.GameMemory) callconv(.c) void,
// update_and_render_fn: *const fn (render_command_buffer: *engine.RenderCommandBuffer, game_memory: *const engine.GameMemory, time_step_s: f64) callconv(.c) void,
//
// pub fn init() GameCode {
//     return .{
//         .init_game_memory_fn = maybe_init_game_memory orelse initGameMemoryStub,
//         .update_and_render_fn = maybe_update_and_render orelse updateAndRenderStub,
//     };
// }
//
// const maybe_init_game_memory = @extern(
//     *const fn (game_memory: *const engine.GameMemory) callconv(.c) void,
//     .{
//         .name = "initGameMemory",
//         .linkage = .weak,
//     },
// );
// const maybe_update_and_render = @extern(
//     *const fn (render_command_buffer: *engine.RenderCommandBuffer, game_memory: *const engine.GameMemory, time_step_s: f64) callconv(.c) void,
//     .{
//         .name = "updateAndRender",
//         .linkage = .weak,
//     },
// );
//
// pub fn initGameMemory(self: GameCode, game_memory: *engine.GameMemory) void {
//     self.init_game_memory_fn(game_memory);
// }
//
// pub fn updateAndRender(self: GameCode, render_command_buffer: *engine.RenderCommandBuffer, game_memory: *const engine.GameMemory, time_step_s: f64) void {
//     self.update_and_render_fn(render_command_buffer, game_memory, time_step_s);
// }
//
// fn initGameMemoryStub(_: *const engine.GameMemory) void {}
// fn updateAndRenderStub(_: *engine.RenderCommandBuffer, _: *const engine.GameMemory, _: f64) void {}
