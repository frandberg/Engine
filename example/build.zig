const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const engine_dep = b.dependency("engine", .{});

    const example_mod = b.createModule(.{
        .root_source_file = b.path("src/example.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("Engine", engine_dep.module("Engine"));

    const example_lib = b.addLibrary(.{
        .name = "example",
        .root_module = example_mod,
        .linkage = .dynamic,
    });
    b.installArtifact(example_lib);

    const engine_exe = engine_dep.artifact("engine");
    engine_exe.linkLibrary(example_lib);
    b.installArtifact(engine_exe);

    std.debug.print("building example", .{});
    const run_cmd = b.addRunArtifact(engine_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addArg("-g");
    run_cmd.addArtifactArg(example_lib);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example application");
    run_step.dependOn(&run_cmd.step);
}
