const std = @import("std");
const glue = @import("glue");

const options = @import("options");

const objc = @import("objc");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const GameCode = @This();

handle: std.DynLib,

init_game_memory_fn: *const glue.IntiGameMemoryFn,
update_and_render_fn: *const glue.UpdateAndRenderFn,

last_change_time: i128,

pub const LibPaths = struct {
    installed: []const u8,
    hot: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) !LibPaths {
        const fw_path_obj = objc.getClass("NSBundle").?.msgSend(
            Object,
            "mainBundle",
            .{},
        ).msgSend(Object, "privateFrameworksPath", .{});

        std.debug.assert(fw_path_obj.value != nil);
        const fw_path = std.mem.span(fw_path_obj.msgSend([*:0]const u8, "UTF8String", .{}));

        var fw_dir = try std.fs.openDirAbsolute(fw_path, .{});
        defer fw_dir.close();

        var iter = fw_dir.iterate();
        const full_name = while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                if (std.mem.containsAtLeast(u8, entry.name, 1, options.lib_name)) {
                    break entry.name;
                }
            }
        } else return error.GameLibNotFound;
        const installed = try std.fs.path.join(allocator, &.{ fw_path, full_name });

        const hot = if (options.hot_reload) blk: {
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
            var app_data_dir = try std.fs.openDirAbsolute(app_data_path, .{});
            defer app_data_dir.close();
            try app_data_dir.makePath("HotReload");

            const hot_path = try std.fs.path.join(allocator, &.{ app_data_path, "HotReload" });
            break :blk try std.fs.path.join(allocator, &.{ hot_path, full_name });
        } else null;

        return .{
            .installed = installed,
            .hot = hot,
        };
    }

    pub fn deinit(self: LibPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.installed);
        if (self.hot) |hot| allocator.free(hot);
    }
};

pub fn updateAndRender(self: *const GameCode, buffer: ?*const glue.OffscreenBufferBGRA8, game_memory: *const glue.GameMemory, delta_time_s: f64) void {
    self.update_and_render_fn(buffer, game_memory, delta_time_s);
}

pub fn initGameMemory(self: *const GameCode, game_memory: *const glue.GameMemory) void {
    self.init_game_memory_fn(game_memory);
}

pub fn load(lib_paths: LibPaths) !GameCode {
    var handle = if (lib_paths.hot) |hot| blk: {
        std.fs.copyFileAbsolute(lib_paths.installed, hot, .{}) catch |err| {
            std.debug.print("Failed to copy game lib from {s} to {s}: {s}\n", .{ lib_paths.installed, hot, @errorName(err) });
            return err;
        };
        break :blk try std.DynLib.open(hot);
    } else try std.DynLib.open(lib_paths.installed);

    errdefer handle.close();

    const init_game_memory_fn = handle.lookup(*const glue.IntiGameMemoryFn, "initGameMemory") orelse return error.FailedToLoadLibFunc;
    const update_and_render_fn = handle.lookup(*const glue.UpdateAndRenderFn, "updateAndRender") orelse return error.FailedToLoadLibFunc;

    return .{
        .handle = handle,

        .init_game_memory_fn = @alignCast(@ptrCast(init_game_memory_fn)),
        .update_and_render_fn = @alignCast(@ptrCast(update_and_render_fn)),

        .last_change_time = try getLastChangedTime(lib_paths.installed),
    };
}
pub fn unload(self: *GameCode) void {
    self.handle.close();
    self.update_and_render_fn = glue.updateAndRenderStub;
    self.init_game_memory_fn = glue.IntiGameMemoryStub;
    self.last_change_time = 0;
}

pub fn isOutOfdate(self: *const GameCode) !bool {
    const current_time = try getLastChangedTime(self.lib_path);
    if (current_time != self.last_change_time) {
        std.debug.assert(current_time > self.last_change_time);
        return true;
    }
    return false;
}

fn getLastChangedTime(lib_path: []const u8) !i128 {
    const lib_file = try std.fs.openFileAbsolute(lib_path, .{ .mode = .read_only });
    defer lib_file.close();
    return (try lib_file.stat()).mtime;
}
