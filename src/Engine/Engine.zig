pub const std = @import("std");

pub const RenderCommandBuffer = @import("RenderCommandBuffer.zig");
pub const math = @import("math");
pub const Input = @import("Input.zig");

pub const GameMemory = @import("GameMemory.zig").GameMemory;
pub const Physics = @import("Physics/Physics.zig");

pub const ecs = @import("ecs");

pub const PhysicsComponents = ecs.PhysicsComponents;
pub const RendererComponents = ecs.RendererComponents;

pub const Sprite = @import("Sprite.zig");
pub const IntiGameMemoryFn = fn (game_memory: *const GameMemory) callconv(.c) void;
pub const UpdateAndRenderFn = fn (
    render_command_recorder: *RenderCommandBuffer,
    game_memory: *const GameMemory,
    delta_time_s: f64,
) callconv(.c) void;

pub fn updateAndRenderStub(_: *RenderCommandBuffer, _: *const GameMemory, _: f64) callconv(.c) void {}
pub fn initGameMemoryStub(_: *const GameMemory) callconv(.c) void {}
