const std = @import("std");
const glue = @import("glue");

const GameCode = @This();

lib_path: ?[]const u8,
handle: ?std.DynLib,
update_and_render_fn: *const glue.UpdateAndRenderFn,

pub const empty: GameCode = .{
    .lib_path = null,
    .handle = null,
    .update_and_render_fn = glue.updateAndRenderStub,
};

pub fn load(lib_path: []const u8) !GameCode {
    var handle = try std.DynLib.open(lib_path);

    const update_and_render_fn = handle.lookup(
        *const glue.UpdateAndRenderFn,
        "updateAndRender",
    ) orelse {
        std.debug.print("failed to load updateAndRender\n", .{});
        return error.FnLoadFailed;
    };
    return .{
        .lib_path = lib_path,
        .handle = handle,
        .update_and_render_fn = update_and_render_fn,
    };
}
pub fn unload(self: *GameCode) void {
    if (self.handle) |*handle| {
        self.update_and_render_fn = glue.updateAndRenderStub;
        handle.close();
    }
}
pub fn reload(self: *GameCode) !void {
    self.unload();
    if (self.lib_path) |lib_path| {
        self.* = try load(lib_path);
        return;
    }
    self.* = .empty;
}

pub fn updateAndRender(self: GameCode, offscreen_buffer: glue.OffscreenBuffer, time_step: f64) void {
    self.update_and_render_fn(offscreen_buffer.ToC(), time_step);
}
