const std = @import("std");

const macos_frameworks: []const []const u8 = &.{
    "CoreFoundation",
    "Appkit",
    "Metal",
    "IOKit",
    "Carbon",
};

const HotReloadConfig = struct {
    src_dir: std.Build.LazyPath,
    args: ?[]const []const u8 = null,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();

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

    const objc_dep = b.dependency("zig_objc", .{});
    const mac_os_mod = b.createModule(.{
        .root_source_file = b.path("src/PlatfromLayer/MacOS/macos.zig"),
        .target = target,
        .optimize = optimize,
    });

    mac_os_mod.addImport("Engine", engine);
    mac_os_mod.addImport("common", platfrom_layer_common);
    mac_os_mod.addImport("objc", objc_dep.module("objc"));

    for (macos_frameworks) |framework_name| {
        mac_os_mod.linkFramework(framework_name, .{});
    }

    const exe = b.addExecutable(.{
        .name = "Engine",
        .root_module = switch (target.result.os.tag) {
            .macos => mac_os_mod,
            else => @panic("Unsupported OS"),
        },
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example application");
    run_step.dependOn(&run_cmd.step);
}
