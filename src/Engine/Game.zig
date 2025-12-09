const std = @import("std");
const foundation = @import("foundation");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const WindowInfo = foundation.WindowInfo;
const RenderCommandBuffer = foundation.Render.CommandBuffer;
const Input = foundation.Input;

pub const Config = struct {
    window_info: WindowInfo = .{
        .width = 800,
        .height = 600,
    },

    //eg 30, 60 etc (Does not affect rendering and fps only how often the update loop is called)
    update_hz: f32 = 30,
    code: Code,
};

pub const Memory = struct {
    permanent: []u8,
    //transient: []u8,

    pub const permanent_storage_size = utils.bytesFromMB(64);
};

pub const Code = struct {
    init_game_memory_fn: *const IntiGameMemoryFn,
    update_and_render_fn: *const UpdateAndRenderFn,

    pub const stub: Code = .{
        .init_game_memory_fn = initGameMemoryStub,
        .update_and_render_fn = updateAndRenderStub,
    };

    pub const IntiGameMemoryFn = fn (game_memory: Memory) void;
    pub const UpdateAndRenderFn = fn (
        game_memory: Memory,
        arena: Allocator,
        render_cmd_buffer: *RenderCommandBuffer,
        input: Input,
        time_step_seconds: f64,
    ) void;

    fn initGameMemoryStub(_: *const Memory) void {}
    fn updateAndRenderStub(_: Memory, _: Allocator, _: *RenderCommandBuffer, _: Input, _: f64) void {}
};
