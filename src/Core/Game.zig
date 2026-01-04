const std = @import("std");
const foundation = @import("foundation");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
const Arena = std.heap.ArenaAllocator;
const StructField = std.builtin.Type.StructField;

const WindowSpec = foundation.WindowSpec;

const Graphics = @import("Graphics/Graphics.zig");

pub const LocalWindowedGame = struct {
    update_fn: UpdateFn,
    render_fn: RenderFn,
};

pub const UpdateFn = fn (
    game_ctx: *anyopaque,
    //input: Input,
    time_step_seconds: f64,
) void;

pub const RenderFn = fn (
    game_ctx: *const anyopaque,
    cmd_buffer: Graphics.CommandBuffer,
) void;
