const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glue = b.addModule("glue", .{
        .root_source_file = b.path("src/glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.addModule("exe", .{
        .root_source_file = b.path("src/MacOS/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("glue", glue);

    const exe = b.addExecutable(.{
        .name = "platform",
        .root_module = exe_mod,
    });
    const run_cmd = b.addRunArtifact(exe);

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
    } else {
        @panic("Only MacOS is suported\n");
    }

    const install_exe = try installExe(b, exe, target, null);
    b.default_step = &install_exe.step;
    run_cmd.step.dependOn(&install_exe.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_cmd.step);
}
pub fn installExe(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    info_plist: ?std.Build.LazyPath,
) !*std.Build.Step.InstallArtifact {
    if (target.result.os.tag == .macos) {
        return installAppBundle(b, exe, info_plist);
    } else @panic("only suppoerts mac os");
}
fn installAppBundle(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    info_plist: ?std.Build.LazyPath,
) !*std.Build.Step.InstallArtifact {
    const bundle_path = try std.fmt.allocPrint(
        b.allocator,
        "{s}.app/Contents/MacOS/{s}",
        .{ exe.name, exe.name },
    );

    const install_exe = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{
            .custom = "bundle/",
        } },
        .dest_sub_path = bundle_path,
    });

    var iter = try std.fs.path.componentIterator(bundle_path);
    _ = iter.first();
    const install_plist_dir = iter.next().?.path;
    const install_plist_path = try std.fs.path.join(b.allocator, &.{ "bundle", install_plist_dir, "info.plist" });
    const install_plist: *std.Build.Step.InstallFile = if (info_plist) |custom|
        b.addInstallFile(custom, install_plist_dir)
    else blk: {
        const info_plist_str = try std.fmt.allocPrint(
            b.allocator,
            @embedFile("MacOS/info.plist"),
            .{ exe.name, exe.name, exe.name, exe.name },
        );
        const wf = b.addWriteFile("info.plist", info_plist_str);
        const install_file = b.addInstallFile(
            try wf.getDirectory().join(b.allocator, "info.plist"),
            install_plist_path,
        );
        install_file.step.dependOn(&wf.step);
        break :blk install_file;
    };
    install_exe.step.dependOn(&install_plist.step);
    return install_exe;
}
