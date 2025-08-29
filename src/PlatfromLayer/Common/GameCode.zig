const std = @import("std");
const engine = @import("Engine");

const options = @import("options");

const objc = @import("objc");

const log = std.log.scoped(.game_code);
const fs = std.fs;

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const GameCode = @This();

init_game_memory_fn: *const engine.IntiGameMemoryFn,
update_and_render_fn: *const engine.UpdateAndRenderFn,

pub const stub: GameCode = .{
    .init_game_memory_fn = engine.IntiGameMemoryStub,
    .update_and_render_fn = engine.updateAndRenderStub,
};

pub const Loader = struct {
    const max_path_len = std.c.PATH_MAX;
    handle: std.DynLib,
    lib_path: []const u8,

    pub fn init(lib_path: []const u8) !?Loader {
        var path_buffer: [max_path_len]u8 = undefined;

        var fba = std.heap.FixedBufferAllocator.init(&path_buffer);
        const path = if (options.hot) blk: {
            const lib_name = std.fs.path.stem(lib_path);
            const app_name = if (std.mem.startsWith(u8, lib_name, "lib")) lib_name[3..] else lib_name;

            const app_data_path = try fs.getAppDataDir(app_name);
            const app_data_dir = try fs.cwd().makeOpenPath();
            defer app_data_dir.close();
            const lib_base_name = fs.path.basename(lib_path);

            fs.cwd().copyFile(lib_path, app_data_dir, lib_base_name);
            break :blk fs.path.join(fba.allocator(), &.{ app_data_path, lib_base_name });
        } else lib_path;
        const handle = std.DynLib.open(path) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    log.warn("Game library not found at {s}: {s}", .{ lib_path, @errorName(err) });
                    return null;
                },
                error.NameTooLong => {
                    log.err("lib name is too long with {} bytes, max length is {}: {s}", .{
                        lib_path.len,
                        max_path_len,
                        lib_path,
                    });
                    return null;
                },
                else => {
                    log.err("unknown error: {s}\n", .{@errorName(err)});
                    return null;
                },
            }
        };

        return .{
            .handle = handle,
            .lib_path = lib_path,
        };
    }

    pub fn deinit(self: *Loader) void {
        self.handle.close();
    }

    pub fn load(self: *Loader) GameCode {
        return .{
            .init_game_memory_fn = self.handle.lookup(*const engine.IntiGameMemoryFn, "initGameMemory") orelse engine.IntiGameMemoryStub,
            .update_and_render_fn = self.handle.lookup(*const engine.UpdateAndRenderFn, "updateAndRender") orelse engine.updateAndRenderStub,
        };
    }

    pub fn reload(self: *Loader) GameCode {
        self.handle.close();
        self = Loader.init(self.lib_path);
        return self.load();
    }
};

pub fn initGameMemory(self: *const GameCode, game_memory: *const engine.GameMemory) void {
    self.init_game_memory_fn(game_memory);
}

pub fn updateAndRender(
    self: *const GameCode,
    render_command_buffer: *engine.RenderCommandBuffer,
    game_memory: *const engine.GameMemory,
    delta_time_s: f64,
) void {
    self.update_and_render_fn(
        render_command_buffer,
        game_memory,
        delta_time_s,
    );
}

fn getLastChangedTime(lib_path: []const u8) !i128 {
    const lib_file = try fs.cwd().openFile(lib_path, .{ .mode = .read_only });
    defer lib_file.close();
    const stat = try lib_file.mtime;
    return stat.mtime;
}
