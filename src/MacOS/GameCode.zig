const std = @import("std");
const glue = @import("glue");

const GameCode = @This();

allocator: std.mem.Allocator,
handle: *anyopaque,
update_and_render_fn: *const glue.UpdateAndRenderFn,
lib_path: []const u8,
tmp_path: []const u8,
last_change_time: i128 = 0,

pub fn load(allocator: std.mem.Allocator, lib_path: []const u8) !GameCode {
    const copied_lib_path = try copyLib(allocator, lib_path);
    const c_path = try std.posix.toPosixPath(copied_lib_path);

    const handle = std.c.dlopen(&c_path, .{ .NOW = true, .LOCAL = true }) orelse return error.FailedToLoadDLL;
    std.debug.print("loading game code\n", .{});
    const func = std.c.dlsym(handle, "updateAndRender") orelse return error.FailedToLoadLibFunc;

    return .{
        .allocator = allocator,
        .handle = handle,
        .update_and_render_fn = @alignCast(@ptrCast(func)),
        .tmp_path = copied_lib_path,
        .lib_path = lib_path,
        .last_change_time = try getLastChangedTime(lib_path),
    };
}
pub fn unload(self: *GameCode) !void {
    if (std.c.dlclose(self.handle) != 0) {
        std.debug.print("failed to  unload dll\n", .{});
    }
    std.debug.print("new path:{s}\n", .{self.tmp_path});
    try std.fs.deleteFileAbsolute(self.tmp_path);
    self.allocator.free(self.tmp_path);
    self.tmp_path = "";
    self.lib_path = "";
    self.update_and_render_fn = glue.updateAndRenderStub;
    self.last_change_time = 0;
}

pub fn getLastChangedTime(lib_path: []const u8) !i128 {
    const lib_file = try std.fs.openFileAbsolute(lib_path, .{ .mode = .read_only });
    defer lib_file.close();
    return (try lib_file.stat()).mtime;
}

fn copyLib(allocator: std.mem.Allocator, lib_path: []const u8) ![]const u8 {
    var cwd = try std.fs.cwd().openDir(".", .{});
    defer cwd.close();
    const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(exe_dir_path);
    const new_file_name = try std.fmt.allocPrint(allocator, "lib-{}.dylib", .{std.time.timestamp()});
    defer allocator.free(new_file_name);
    const new_path = try std.fs.path.join(allocator, &.{ exe_dir_path, new_file_name });
    std.debug.print("is absolute: {}\n", .{std.fs.path.isAbsolute(new_path)});

    const abs_lib_path = if (std.fs.path.isAbsolute(lib_path)) lib_path else try cwd.realpathAlloc(
        allocator,
        lib_path,
    );
    try std.fs.copyFileAbsolute(abs_lib_path, new_path, .{});
    return new_path;
}
