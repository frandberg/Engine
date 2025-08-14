const std = @import("std");
const glue = @import("glue");

const options = @import("options");

const objc = @import("objc");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const GameCode = @This();

init_game_memory_fn: *const glue.IntiGameMemoryFn,
update_and_render_fn: *const glue.UpdateAndRenderFn,

pub const stub: GameCode = .{
    .init_game_memory_fn = glue.IntiGameMemoryStub,
    .update_and_render_fn = glue.updateAndRenderStub,
};

pub const Loader = struct {
    handle: ?std.DynLib,
    last_change_time: i128,
    installed_path: []const u8,
    hot_reload_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, lib_path: []const u8, hot_reload: bool) !?Loader {
        const lib_name = blk: {
            var iter = try std.fs.path.componentIterator(lib_path);
            break :blk iter.last().?.name;
        };

        const hot_reload_path = if (hot_reload) blk: {
            const bundle_identifier = std.mem.span(
                objc.getClass("NSBundle").?.msgSend(Object, "mainBundle", .{}).msgSend(
                    Object,
                    "bundleIdentifier",
                    .{},
                ).msgSend(
                    [*:0]const u8,
                    "UTF8String",
                    .{},
                ),
            );

            const app_data_path: []const u8 = try std.fs.getAppDataDir(allocator, bundle_identifier);
            defer allocator.free(app_data_path);

            var app_data_base_dir = try std.fs.openDirAbsolute(std.fs.path.dirname(app_data_path).?, .{});
            defer app_data_base_dir.close();
            try app_data_base_dir.makePath(bundle_identifier);

            var app_data_dir = try std.fs.openDirAbsolute(app_data_path, .{});
            defer app_data_dir.close();
            try app_data_dir.makePath("HotReload");

            const hot_path = try std.fs.path.join(allocator, &.{ app_data_path, "HotReload" });
            defer allocator.free(hot_path);
            break :blk try std.fs.path.join(allocator, &.{ hot_path, lib_name });
        } else null;

        return .{
            .handle = null,
            .last_change_time = try getLastChangedTime(lib_path),
            .installed_path = lib_path,
            .hot_reload_path = hot_reload_path,
        };
    }

    pub fn deinit(self: *Loader, allocator: std.mem.Allocator) void {
        self.unload();
        if (self.hot_reload_path) |hot_path| {
            allocator.free(hot_path);
        }
    }

    pub fn load(self: *Loader) !GameCode {
        if (self.hot_reload_path) |hot_path| {
            std.fs.copyFileAbsolute(self.installed_path, hot_path, .{}) catch |err| {
                std.debug.print("Failed to copy game lib from {s} to {s}: {s}\n", .{ self.installed_path, hot_path, @errorName(err) });
                return err;
            };
            self.handle = std.DynLib.open(hot_path) catch |err| {
                std.debug.print("Failed to open hot reload lib {s}: {s}\n", .{ hot_path, @errorName(err) });
                return err;
            };
        } else {
            self.handle = std.DynLib.open(self.installed_path) catch |err| {
                std.debug.print("Failed to open game lib {s}: {s}\n", .{ self.installed_path, @errorName(err) });
                return err;
            };
        }

        if (self.handle) |*handle| {
            const init_game_memory_fn = handle.lookup(*const glue.IntiGameMemoryFn, "initGameMemory") orelse return error.FailedToLoadLibFunc;
            const update_and_render_fn = handle.lookup(*const glue.UpdateAndRenderFn, "updateAndRender") orelse return error.FailedToLoadLibFunc;

            return .{
                .init_game_memory_fn = @alignCast(@ptrCast(init_game_memory_fn)),
                .update_and_render_fn = @alignCast(@ptrCast(update_and_render_fn)),
            };
        }
        return .stub;
    }

    pub fn unload(self: *Loader) void {
        if (self.handle) |*handle| {
            handle.close();
            self.handle = null;
        }

        self.last_change_time = 0;
    }

    pub fn needsReload(self: *Loader) !bool {
        if (self.handle == null) return false;

        const last_changed_time = try getLastChangedTime(self.installed_path);

        if (last_changed_time > self.last_change_time) {
            self.last_change_time = last_changed_time;
            return true;
        }
        return false;
    }
};

pub fn updateAndRender(self: *const GameCode, buffer: ?*const glue.OffscreenBufferBGRA8, game_memory: *const glue.GameMemory, delta_time_s: f64) void {
    self.update_and_render_fn(buffer, game_memory, delta_time_s);
}

pub fn initGameMemory(self: *const GameCode, game_memory: *const glue.GameMemory) void {
    self.init_game_memory_fn(game_memory);
}

fn getLastChangedTime(lib_path: []const u8) !i128 {
    const lib_file = try std.fs.openFileAbsolute(lib_path, .{ .mode = .read_only });
    defer lib_file.close();
    return (try lib_file.stat()).mtime;
}
