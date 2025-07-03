const std = @import("std");
const pl = @import("platform_layer");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const platform_layer_dep = b.dependency("platform_layer", .{});
    lib_mod.addImport("glue", platform_layer_dep.module("glue"));

    const lib = b.addLibrary(.{
        .name = "my-game",
        .root_module = lib_mod,
        .linkage = .dynamic,
    });

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = platform_layer_dep.module("exe_mod"),
    });

    const platform_options: pl.PlatformOptions = .{
        .macos = .{
            .bundle_name = "example",
            .exe_name = exe.name,
        },
    };

    const install_exe = try pl.installArtifact(b, exe, target, optimize, platform_options);
    const install_lib = try pl.installArtifact(b, lib, target, optimize, platform_options);
    const install_files = try pl.installPlatformFiles(b, target, optimize, platform_options);

    const install_step = b.getInstallStep();
    install_step.dependOn(&install_exe.step);
    install_step.dependOn(&install_lib.step);
    install_step.dependOn(&install_files.step);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addArg("--game-lib");
    run_cmd.addArtifactArg(lib);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
