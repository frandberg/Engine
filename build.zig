const std = @import("std");

const macos_frameworks: []const []const u8 = &.{
    "CoreFoundation",
    "Appkit",
    "Metal",
    "IOKit",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_only_build = b.option(bool, "lib-only", "only build the library (ment for hot releod of examples)") orelse false;
    const hot_reloadable = b.option(bool, "hot", "should the engine eneble hot reloading of the game code") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "hot", hot_reloadable);

    const exe_root_source_file = switch (target.result.os.tag) {
        .macos => b.path("src/PlatfromLayer/MacOS/main.zig"),
        else => @panic("Unsupported OS"),
    };

    const engine = b.addModule("Engine", .{
        .root_source_file = b.path("src/Engine/Engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const options_mod = options.createModule();

    const platfrom_layer_common = b.addModule("PlatformLayerCommon", .{
        .root_source_file = b.path("src/PlatfromLayer/Common/Common.zig"),
        .target = target,
        .optimize = optimize,
    });
    platfrom_layer_common.addImport("Engine", engine);
    platfrom_layer_common.addImport("options", options_mod);

    const exe_mod = b.createModule(
        .{
            .root_source_file = exe_root_source_file,
            .target = target,
            .optimize = optimize,
        },
    );
    exe_mod.addImport("options", options_mod);
    exe_mod.addImport("common", platfrom_layer_common);
    exe_mod.addImport("Engine", engine);

    if (target.result.os.tag == .macos) {
        const objc_dep = b.dependency("objc", .{});
        exe_mod.addImport("objc", objc_dep.module("objc"));
        for (macos_frameworks) |framework_name| {
            exe_mod.linkFramework(framework_name, .{});
        }
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
    example_mod.addImport("Engine", engine);

    const example_lib = b.addLibrary(.{
        .name = "example",
        .root_module = example_mod,
        .linkage = .dynamic,
    });

    if (!lib_only_build) {
        b.installArtifact(exe);
    }
    b.installArtifact(example_lib);

    const example_step = b.step("example", "build the example");
    example_step.dependOn(b.getInstallStep());

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(example_step);

    run_cmd.addArgs(&.{
        "--game",
    });

    run_cmd.addArtifactArg(example_lib);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run-example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
