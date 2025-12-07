const std = @import("std");
const engine = @import("Engine");

const log = std.log.scoped(.game_code);
const GameCode = @This();

const initGameMemoryT = *const @TypeOf(initGameMemoryStub);
const updateAndRenderT = *const @TypeOf(updateAndRenderStub);

handle: ?std.DynLib,
init_game_memory_fn: initGameMemoryT,
update_and_render_fn: updateAndRenderT,

pub fn init(lib_path: ?[]const u8) !GameCode {
    if (lib_path) |path| {
        std.debug.print("Loading game code from: {s}\n", .{path});
        var handle = try std.DynLib.open(path);
        const init_game_memory_fn = handle.lookup(initGameMemoryT, "initGameMemory") orelse blk: {
            log.err("initGameMemory was not found", .{});
            break :blk &initGameMemoryStub;
        };
        const update_and_render_fn = handle.lookup(updateAndRenderT, "updateAndRender") orelse blk: {
            log.err("initGameMemory was not found", .{});
            break :blk &updateAndRenderStub;
        };

        return .{
            .handle = handle,
            .init_game_memory_fn = init_game_memory_fn,
            .update_and_render_fn = update_and_render_fn,
        };
    } else {
        return .{
            .handle = null,
            .init_game_memory_fn = &initGameMemoryStub,
            .update_and_render_fn = &updateAndRenderStub,
        };
    }
}

pub fn deinit(self: *GameCode) void {
    if (self.handle) |*handle| {
        handle.close();
    }
}

pub fn initGameMemory(self: *const GameCode, game_memory: *const engine.GameMemory) void {
    self.init_game_memory_fn(game_memory);
}

pub fn updateAndRender(
    self: *const GameCode,
    render_command_buffer: *engine.RenderCommandBuffer,
    game_memory: *const engine.GameMemory,
    arena: *const std.mem.Allocator,
    input: *const engine.Input,
    time_step_s: f64,
) void {
    self.update_and_render_fn(render_command_buffer, game_memory, arena, input, time_step_s);
}

fn initGameMemoryStub(_: *const engine.GameMemory) callconv(.c) void {}
fn updateAndRenderStub(_: *engine.RenderCommandBuffer, _: *const engine.GameMemory, _: *const std.mem.Allocator, _: *const engine.Input, _: f64) callconv(.c) void {}
