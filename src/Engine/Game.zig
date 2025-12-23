const std = @import("std");
const foundation = @import("foundation");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const FixedBufferAllocator = std.heap.FixedBufferAllocator;
const Arena = std.heap.ArenaAllocator;
const WindowInfo = foundation.WindowInfo;
const RenderCommandBuffer = foundation.Render.CommandBuffer;
const Input = foundation.Input;

const Render = @import("Render.zig");

pub const Config = struct {
    window_info: WindowInfo = .{
        .width = 800,
        .height = 600,
        .title = "Game",
    },

    //eg 30, 60 etc (Does not affect rendering and fps only how often the update loop is called)
    update_hz: f32 = 30,
    code: Code,
};

pub const Code = struct {
    update_and_render_fn: *const UpdateAndRenderFn,

    pub fn makeWrapper(
        comptime GameT: type,
        comptime update_and_render_fn: fn (
            game: *GameT,
            arena: Allocator,
            render_ctx: Render.Context,
            //input: Input,
            time_step: f64,
        ) void,
    ) Code {
        const Wrapper = struct {
            fn updateAndRenderWrapper(
                game_state: *anyopaque,
                arena: Allocator,
                render_ctx: Render.Context,
                //input: Input,
                time_step: f64,
            ) void {
                update_and_render_fn(
                    @ptrCast(@alignCast(game_state)),
                    arena,
                    render_ctx,
                    //input,
                    time_step,
                );
            }
        };

        return .{
            .update_and_render_fn = Wrapper.updateAndRenderWrapper,
        };
    }

    pub const stub: Code = .{
        .update_and_render_fn = updateAndRenderStub,
    };

    pub const UpdateAndRenderFn = fn (
        game: *anyopaque,
        arena: Allocator,
        render_ctx: Render.Context,
        //input: Input,
        time_step_seconds: f64,
    ) void;

    fn updateAndRenderStub(_: *anyopaque, _: Allocator, _: Render.Context, _: Input, _: f64) void {}
};
