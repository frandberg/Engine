const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_name: []const u8 = b.option([]const u8, "lib_name", "name of the dynamic game lib to be used for loading at runtime") orelse return error.NoLibName;

    const hot_reload: bool = b.option(
        bool,
        "enable_hot_reload",
        "Enable hot reloading of the game code",
    ) orelse false;

    const options = b.addOptions();

    options.addOption([]const u8, "lib_name", lib_name);
    options.addOption(bool, "hot_reload", hot_reload);

    const glue = b.addModule("glue", .{
        .root_source_file = b.path("src/glue.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.addModule("exe_mod", .{
        .root_source_file = b.path("src/MacOS/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{
            .name = "glue",
            .module = glue,
        }},
    });
    exe_mod.addImport("options", options.createModule());

    if (target.result.os.tag == .macos) {
        const objc_dep = b.dependency("objc", .{});
        exe_mod.addImport("objc", objc_dep.module("objc"));
        exe_mod.linkFramework("Appkit", .{});
        exe_mod.linkFramework("Metal", .{});
        exe_mod.linkFramework("CoreFoundation", .{});
    } else {
        return error.UnsuportedOS;
    }
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

    const target_path = try std.fmt.allocPrint(
        b.allocator,
        "{s}-{s}/{s}/",
        .{
            @tagName(target.result.os.tag),
            @tagName(target.result.cpu.arch),
            @tagName(optimize),
        },
    );

    switch (target.result.os.tag) {
        .macos => {
            const exe_install_dir: std.Build.InstallDir = .{
                .custom = try std.fmt.allocPrint(b.allocator, "bundle/{s}/{s}.app/Contents/MacOS/", .{ target_path, options.mac_os.bundle_name }),
            };

            const lib_install_dir: std.Build.InstallDir = .{
                .custom = try std.fmt.allocPrint(b.allocator, "bundle/{s}/{s}.app/Contents/Frameworks/", .{ target_path, options.mac_os.bundle_name }),
            };
            const info_plist_install_dir: std.Build.InstallDir = .{
                .custom = try std.fmt.allocPrint(b.allocator, "bundle/{s}/{s}.app/Contents/", .{ target_path, options.mac_os.bundle_name }),
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

            const install_exe = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = exe_install_dir } });
            const install_lib = b.addInstallArtifact(lib, .{ .dest_dir = .{ .override = lib_install_dir } });

            const install_step = b.getInstallStep();

            install_step.dependOn(&install_info_plist.step);
            install_step.dependOn(&install_exe.step);
            install_step.dependOn(&install_lib.step);
        },
        else => std.debug.panic("Unsupported OS {}", .{target.result.os.tag}),
    }
}
