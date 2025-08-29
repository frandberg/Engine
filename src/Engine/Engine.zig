pub const std = @import("std");

pub const RenderCommandBuffer = @import("RenderCommandBuffer.zig");
pub const math = @import("math.zig");

pub const GameMemory = @import("GameMemory.zig").GameMemory;

pub const IntiGameMemoryFn = fn (game_memory: *const GameMemory) callconv(.c) void;
pub const UpdateAndRenderFn = fn (
    render_command_recorder: *RenderCommandBuffer,
    game_memory: *const GameMemory,
    delta_time_s: f64,
) callconv(.c) void;

pub fn updateAndRenderStub(_: *RenderCommandBuffer, _: *const GameMemory, _: f64) callconv(.c) void {}
pub fn IntiGameMemoryStub(_: *const GameMemory) callconv(.c) void {}
