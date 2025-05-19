const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("glue", .{
        .root_source_file = b.path("src/glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/MacOS/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "game",
        .root_module = exe_mod,
    });

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("objc", .{})) |dep| {
            exe_mod.addImport("objc", dep.module("objc"));
        }

        exe_mod.linkFramework("Appkit", .{});
        exe_mod.linkFramework("Foundation", .{});
        exe_mod.linkFramework("QuartzCore", .{});
        exe_mod.linkFramework("Metal", .{});
        exe_mod.linkFramework("MetalKit", .{});

        exe_mod.addCSourceFile(.{
            .file = b.path("src/MacOS/Delegate.m"),
            .flags = &.{},
        });

        const run_cmd = try createAppBundleAndRunCmd(
            b,
            exe.getEmittedBin(),
            null,
            b.path("MacOS/info.plist"),
            "game",
        );

        const run_step = b.step("run", "run the app");
        run_step.dependOn(&run_cmd.step);
    } else {
        return error{UnsuportedOS}.UnsuportedOS;
    }
    b.installArtifact(exe);
}

pub fn createAppBundleAndRunCmd(
    b: *std.Build,
    exe_path: std.Build.LazyPath,
    lib_path: ?std.Build.LazyPath,
    info_plist: std.Build.LazyPath,
    game_name: []const u8,
) !*std.Build.Step.Run {
    var full_path = try std.BoundedArray(u8, 2048).init(0);
    try full_path.appendSlice(b.install_prefix);

    try full_path.append('/');
    try full_path.appendSlice(game_name);
    try full_path.appendSlice(".app/");

    const bundle_path = full_path.slice();
    try full_path.appendSlice("Contents/");
    try full_path.appendSlice("MacOS/");

    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", full_path.slice() });
    mkdir.step.dependOn(b.getInstallStep());

    try full_path.appendSlice(game_name);
    const copy_exe = b.addSystemCommand(&.{"cp"});
    copy_exe.addFileArg(exe_path);
    copy_exe.addArg(full_path.slice());
    copy_exe.step.dependOn(&mkdir.step);

    var info_plist_path = try std.BoundedArray(u8, 2048).init(0);
    try info_plist_path.appendSlice(bundle_path);
    try info_plist_path.appendSlice("info.plist");

    const copy_info_plist = b.addSystemCommand(&.{"cp"});
    copy_info_plist.addFileArg(info_plist);
    copy_info_plist.addArg(info_plist_path.slice());
    copy_info_plist.step.dependOn(&mkdir.step);

    const run_cmd = b.addSystemCommand(&.{full_path.slice()});
    run_cmd.step.dependOn(&copy_exe.step);

    run_cmd.step.dependOn(&copy_info_plist.step);
    if (lib_path) |lib| {
        run_cmd.addArg("-lib");
        run_cmd.addFileArg(lib);
    }

    return run_cmd;
}
