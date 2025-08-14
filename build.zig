const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();

    const exe_root_source_file = switch (target.result.os.tag) {
        .macos => b.path("src/PlatfromLayer/MacOS/main.zig"),
        else => @panic("Unsupported OS"),
    };

    const glue = b.addModule("glue", .{
        .root_source_file = b.path("src/glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const platfrom_layer_common = b.addModule("PlatformLayerCommon", .{
        .root_source_file = b.path("src/PlatfromLayer/Common/Common.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(
        .{
            .root_source_file = exe_root_source_file,
            .target = target,
            .optimize = optimize,
        },
    );
    exe_mod.addImport("glue", glue);
    exe_mod.addImport("options", options.createModule());
    exe_mod.addImport("common", platfrom_layer_common);

    if (target.result.os.tag == .macos) {
        const objc_dep = b.dependency("objc", .{});
        exe_mod.addImport("objc", objc_dep.module("objc"));
        exe_mod.linkFramework("Appkit", .{});
        exe_mod.linkFramework("Metal", .{});
        exe_mod.linkFramework("CoreFoundation", .{});
    } else {
        return error.UnsuportedOS;
    }

    const exe = b.addExecutable(.{
        .name = "exe",
        .root_module = exe_mod,
    });

    const example_mod = b.createModule(.{
        .root_source_file = b.path("example/src/example.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("glue", glue);

    const example_lib = b.addLibrary(.{
        .name = "example",
        .root_module = example_mod,
        .linkage = .dynamic,
    });

    install(b, exe, example_lib, .{
        .mac_os = .{
            .bundle_identifier = "com.example.game",
            .bundle_name = "Example",
        },
        .target = target,
        .optimize = optimize,
    }) catch |err| {
        std.debug.print("Failed to install example: {s}\n", .{@errorName(err)});
        return err;
    };

    const example_step = b.step("example", "build the example");
    example_step.dependOn(b.getInstallStep());

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(example_step);

    run_cmd.addArgs(&.{
        "--hot",
        "--game",
    });

    run_cmd.addArtifactArg(example_lib);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}

pub const Options = struct {
    mac_os: MacOS,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,

    const MacOS = struct {
        bundle_identifier: []const u8,
        bundle_name: []const u8,
        bundle_short_version_string: []const u8 = "1.0",
        bundle_version: []const u8 = "1.0",
    };
};

pub fn install(b: *std.Build, exe: *std.Build.Step.Compile, lib: *std.Build.Step.Compile, options: Options) !void {
    const target = options.target;
    const optimize = options.optimize;

    const sub_path = try installSubPath(b.allocator, target, optimize);

    switch (target.result.os.tag) {
        .macos => {
            const info_plist_install_dir: std.Build.InstallDir = .{
                .custom = try std.fmt.allocPrint(b.allocator, "bundle/{s}/{s}.app/Contents/", .{ sub_path, options.mac_os.bundle_name }),
            };

            const write_info_plist = b.addWriteFile("Info.plist", try std.fmt.allocPrint(
                b.allocator,
                @embedFile("MacOS/InfoPlist-template.txt"),
                .{
                    options.mac_os.bundle_name,
                    options.mac_os.bundle_identifier,
                    options.mac_os.bundle_version,
                    options.mac_os.bundle_short_version_string,
                    exe.name,
                },
            ));

            const install_info_plist = b.addInstallFileWithDir(
                try write_info_plist.getDirectory().join(b.allocator, "Info.plist"),
                info_plist_install_dir,
                "Info.plist",
            );

            const install_exe = try MacOS_install_artifact(
                b,
                exe,
                sub_path,
                options.mac_os.bundle_name,
            );

            const install_lib = try MacOS_install_artifact(
                b,
                lib,
                sub_path,
                options.mac_os.bundle_name,
            );

            const install_step = b.getInstallStep();

            install_step.dependOn(&install_info_plist.step);
            install_step.dependOn(&install_exe.step);
            install_step.dependOn(&install_lib.step);
        },
        else => std.debug.panic("Unsupported OS {}", .{target.result.os.tag}),
    }
}

fn MacOS_install_artifact(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    sub_path: []const u8,
    bundle_name: []const u8,
) !*std.Build.Step.InstallArtifact {
    const kind_str = switch (artifact.kind) {
        .exe => "MacOS/",
        .lib => "Frameworks/",
        else => unreachable,
    };
    const install_dir: std.Build.InstallDir = .{
        .custom = try std.fmt.allocPrint(
            b.allocator,
            "bundle/{s}/{s}.app/Contents/{s}",
            .{ sub_path, bundle_name, kind_str },
        ),
    };

    return b.addInstallArtifact(
        artifact,
        .{ .dest_dir = .{ .override = install_dir } },
    );
}

fn installSubPath(allocator: std.mem.Allocator, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}-{s}/{s}/",
        .{
            @tagName(target.result.os.tag),
            @tagName(target.result.cpu.arch),
            @tagName(optimize),
        },
    );
}
