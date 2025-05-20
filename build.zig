const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const game_name = "game";

    const glue = b.addModule("glue", .{
        .root_source_file = b.path("src/glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("glue", glue);

    const exe = b.addExecutable(.{
        .name = "platform",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = try createRunCmd(b, target, null, game_name);

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("objc", .{})) |dep| {
            exe_mod.addImport("objc", dep.module("objc"));
        }

        exe_mod.linkFramework("Appkit", .{});
        exe_mod.linkFramework("Foundation", .{});
        exe_mod.linkFramework("QuartzCore", .{});
        exe_mod.linkFramework("MetalKit", .{});
        exe_mod.linkFramework("Metal", .{});

        exe_mod.addCSourceFile(.{
            .file = b.path("src/MacOS/Protocols.m"),
            .flags = &.{},
        });
        const create_bundle_step = try createAppBundle(
            b,
            exe.getEmittedBin(),
            b.path("MacOS/info.plist"),
            game_name,
        );
        b.default_step = create_bundle_step;
        run_cmd.step.dependOn(create_bundle_step);
    } else {
        @panic("Only MacOS is suported\n");
    }
    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_cmd.step);
}

pub fn createRunCmd(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    lib_path: ?std.Build.LazyPath,
    game_name: []const u8,
) !*std.Build.Step.Run {
    if (target.result.os.tag == .macos) {
        var buffer: [2048]u8 = undefined;
        const exe_run_path = try bundleExePath(b.install_prefix, game_name, &buffer);

        const run_cmd = b.addSystemCommand(&.{exe_run_path});

        if (lib_path) |lib| {
            run_cmd.addArg("-lib");
            run_cmd.addFileArg(lib);
        }
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        return run_cmd;
    }
    @panic("Only MacOS is suported\n");
}

pub fn createAppBundle(
    b: *std.Build,
    exe_path: std.Build.LazyPath,
    info_plist: std.Build.LazyPath,
    game_name: []const u8,
) !*std.Build.Step {
    var buffer: [2048]u8 = undefined;
    const bundle_exe_path = try bundleExePath(b.install_prefix, game_name, &buffer);
    var path_iter = try std.fs.path.componentIterator(bundle_exe_path);

    _ = path_iter.last();
    const bundle_exe_dir = path_iter.previous().?.path;
    _ = path_iter.previous();
    const info_plist_dir = path_iter.previous().?.path;

    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", bundle_exe_dir });
    mkdir.step.dependOn(b.getInstallStep());

    const copy_exe = b.addSystemCommand(&.{"cp"});
    copy_exe.addFileArg(exe_path);
    copy_exe.addArg(bundle_exe_path);
    copy_exe.step.dependOn(&mkdir.step);

    const copy_info_plist = b.addSystemCommand(&.{"cp"});
    copy_info_plist.addFileArg(info_plist);
    copy_info_plist.addArg(info_plist_dir);
    copy_info_plist.step.dependOn(&mkdir.step);

    var create_bundle_step = b.step("bundle", "creates and app bundle");
    create_bundle_step.dependOn(&copy_exe.step);
    create_bundle_step.dependOn(&copy_info_plist.step);
    return create_bundle_step;
}
fn bundleExePath(build_prefix: []const u8, game_name: []const u8, buffer: []u8) ![]const u8 {
    var allocator = std.heap.FixedBufferAllocator.init(buffer);

    return std.mem.join(
        allocator.allocator(),
        "",
        &.{ build_prefix, "/MacOS/", game_name, ".app/Contents/MacOS/", game_name },
    );
}
