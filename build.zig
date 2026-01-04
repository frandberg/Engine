const std = @import("std");

const macos_frameworks: []const []const u8 = &.{
    "CoreFoundation",
    "Appkit",
    "Metal",
    "Carbon",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const math = b.createModule(.{
        .root_source_file = b.path("src/math/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const utils = b.createModule(.{
        .root_source_file = b.path("src/Utils/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const core = b.createModule(.{
        .root_source_file = b.path("src/Core/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine = b.addModule("Engine", .{
        .root_source_file = b.path("src/Engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const platform = switch (target.result.os.tag) {
        .macos => blk: {
            const objc_dep = b.dependency("zig_objc", .{});
            const mac_os_mod = b.createModule(.{
                .root_source_file = b.path("src/Platform/MacOS/root.zig"),
                .target = target,
                .optimize = optimize,
            });
            mac_os_mod.addImport("core", core);
            mac_os_mod.addImport("objc", objc_dep.module("objc"));
            mac_os_mod.addImport("math", math);

            for (macos_frameworks) |framework_name| {
                mac_os_mod.linkFramework(framework_name, .{});
            }
            break :blk mac_os_mod;
        },
        else => @panic("Unsupported OS"),
    };

    core.addImport("math", math);
    core.addImport("utils", utils);

    engine.addImport("math", math);
    engine.addImport("utils", utils);
    engine.addImport("core", core);
    engine.addImport("platform", platform);
}
