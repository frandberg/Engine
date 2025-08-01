const std = @import("std");
const pl = @import("platform_layer");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib_name: []const u8 = "my-game";

    const platform_layer_dep = b.dependency("platform_layer", .{
        .target = target,
        .optimize = optimize,
        .lib_name = lib_name,
        .enable_hot_reload = true,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("glue", platform_layer_dep.module("glue"));

    const lib = b.addLibrary(.{
        .name = lib_name,
        .root_module = lib_mod,
        .linkage = .dynamic,
    });

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = platform_layer_dep.module("exe_mod"),
    });

    try pl.install(b, exe, lib, .{
        .target = target,
        .optimize = optimize,
        .mac_os = .{
            .bundle_identifier = "com.example.my-game",
            .bundle_name = "Example",
        },
    });

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
