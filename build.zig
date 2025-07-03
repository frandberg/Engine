const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_grpahics = b.addModule("CoreGraphics", .{
        .root_source_file = b.path("src/MacOS/CoreGraphics/CoreGraphics.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cocoa = b.addModule("Cocoa", .{
        .root_source_file = b.path("src/MacOS/Cocoa/Cocoa.zig"),
        .target = target,
        .optimize = optimize,
    });

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

    cocoa.addImport("CoreGraphics", core_grpahics);
    exe_mod.addImport("CoreGraphics", core_grpahics);
    exe_mod.addImport("Cocoa", cocoa);

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("objc", .{})) |dep| {
            exe_mod.addImport("objc", dep.module("objc"));
            cocoa.addImport("objc", dep.module("objc"));
        }
        exe_mod.linkFramework("Appkit", .{});
        exe_mod.linkFramework("Metal", .{});
    } else {
        return error.UnsuportedOS;
    }
}

pub const PlatformOptions = struct {
    macos: MacOSOptions,
    pub const MacOSOptions = struct {
        bundle_name: []const u8,
        exe_name: []const u8,
    };
};

pub fn installPlatformFiles(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    platform_options: PlatformOptions,
) !*std.Build.Step.InstallFile {
    if (target.result.os.tag == .macos) {
        const bundle_name = platform_options.macos.bundle_name;
        const exe_name = platform_options.macos.exe_name;
        const info_plist_str = try std.fmt.allocPrint(
            b.allocator,
            @embedFile("MacOS/Info.plist"),
            .{ bundle_name, bundle_name, bundle_name, exe_name },
        );

        const prefix = try installPrefix(b, target, optimize);
        const info_plist_dest_path = try std.fmt.allocPrint(
            b.allocator,
            "{s}{s}.app/Contents/Info.plist",
            .{ prefix, bundle_name },
        );

        const wf = b.addWriteFile("Info.plist", info_plist_str);
        const install_file = b.addInstallFile(
            try wf.getDirectory().join(b.allocator, "Info.plist"),
            info_plist_dest_path,
        );
        install_file.step.dependOn(&wf.step);
        return install_file;
    } else return error.UnsuportedOS;
}

pub fn installArtifact(
    b: *std.Build,
    compile: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    platform_options: PlatformOptions,
) !*std.Build.Step.InstallArtifact {
    const prefix = try installPrefix(b, target, optimize);
    const install_dir: std.Build.InstallDir = if (target.result.os.tag == .macos) blk: {
        const bundle_name = platform_options.macos.bundle_name;
        const sub_path = if (compile.kind == .exe)
            try std.fmt.allocPrint(b.allocator, "{s}.app/Contents/MacOS/", .{bundle_name})
        else if (compile.kind == .lib)
            try std.fmt.allocPrint(b.allocator, "{s}.app/Contents/Frameworks/", .{bundle_name})
        else
            return error.UnsuportedArtifact;

        const path = try std.fs.path.join(b.allocator, &.{ prefix, sub_path });
        break :blk .{ .custom = path };
    } else return error.UnsuportedOS;

    return b.addInstallArtifact(compile, .{ .dest_dir = .{
        .override = install_dir,
    } });
}
fn installPrefix(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ![]const u8 {
    return std.fmt.allocPrint(
        b.allocator,
        "{s}-{s}/{s}/",
        .{
            @tagName(target.result.os.tag),
            @tagName(target.result.cpu.arch),
            @tagName(optimize),
        },
    );
}
