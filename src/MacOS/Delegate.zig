const std = @import("std");
const objc = @import("objc");
const glue = @import("glue");
const ns = @import("Cocoa.zig");
const GameCode = @import("GameCode.zig");
const MacOSOffscreenBuffer = @import("MacOSOffscreenBuffer.zig");

extern "Metal" fn MTLCreateSystemDefaultDevice() callconv(.C) ?*objc.c.struct_objc_object;

const Object = objc.Object;
const Id = objc.c.id;
const Delegate = @This();

pub const Runtime = struct {
    // game_code: GameCode,

    offscreen_buffer: MacOSOffscreenBuffer,
};
var lib_path: ?[]const u8 = null;

obj: Object,

pub fn init(maybe_lib_path: ?[]const u8) !Delegate {
    lib_path = maybe_lib_path;
    app().msgSend(void, "activateIgnoringOtherApps:", .{true});
    const DelegateClass = try createDelegateClass();
    const self: Delegate = .{ .obj = DelegateClass.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{}) };

    const MTKView = objc.getClass("MyMTKView").?;

    const runtime = std.heap.page_allocator.create(Runtime) catch @panic("OOM");
    const window = initWindow(800, 600);
    const frame = window.msgSend(ns.Rect, "frame", .{});
    const view = MTKView.msgSend(Object, "alloc", .{}).msgSend(Object, "initWithFrame:", .{
        frame,
    });

    const mtl_device: Object = .{ .value = MTLCreateSystemDefaultDevice().? };
    self.obj.setInstanceVariable("mtl_device", mtl_device);

    window.msgSend(void, "setDelegate:", .{self.obj});
    window.msgSend(void, "makeKeyAndOrderFront:", .{null});
    window.msgSend(void, "setContentView:", .{view});
    window.msgSend(void, "makeFirstResponder:", .{view});
    window.msgSend(void, "setAcceptsMouseMovedEvents:", .{true});

    view.msgSend(void, "setDevice:", .{mtl_device});
    view.msgSend(void, "setDelegate:", .{self.obj});
    view.msgSend(void, "setWantsLayer:", .{1});
    view.msgSend(void, "becomeFirstResponder", .{});

    const mtl_cmd_queue: Object = mtl_device.msgSend(Object, "newCommandQueue", .{});
    self.obj.setInstanceVariable("mtl_cmd_queue", mtl_cmd_queue);

    const offscreen_buffer = MacOSOffscreenBuffer.init(
        std.heap.page_allocator,
        mtl_device,
        800,
        600,
    );
    runtime.* = .{
        // .game_code = if (maybe_lib_path) |lib_path| try GameCode.load(lib_path) else .empty,
        .offscreen_buffer = offscreen_buffer,
    };

    _ = objc.c.object_setInstanceVariable(self.obj.value, "runtime", runtime);

    return self;
}

fn initWindow(width: f64, height: f64) objc.Object {
    const NSWindow = objc.getClass("NSWindow").?;

    const NSScreen = objc.getClass("NSScreen").?;
    const main_screen = NSScreen.msgSend(objc.Object, "mainScreen", .{});
    const scale = main_screen.msgSend(f64, "backingScaleFactor", .{});

    const style_mask: usize = 1 | (1 << 1) | (1 << 2) | (1 << 3);
    const rect: ns.Rect = .{
        .origin = .{
            .x = 0,
            .y = 0,
        },
        .size = .{
            .width = width / scale,
            .height = height / scale,
        },
    };
    return NSWindow.msgSend(objc.Object, "alloc", .{}).msgSend(
        objc.Object,
        "initWithContentRect:styleMask:backing:defer:",
        .{
            rect,
            style_mask,
            2, //NSBackingStoreBuffer
            false, //defer
        },
    );
}
fn update(self_id: Id, _: objc.c.SEL, view_id: Id) callconv(.c) void {
    const self: Delegate = .{ .obj = .{ .value = self_id } };

    const view: Object = .{ .value = view_id };
    _ = view;
    const runtime = self.getRuntime();

    dllStuff(runtime.offscreen_buffer) catch @panic("dll stuff failed");
    // displayOffscreenBuffer(runtime.offscreen_buffer, self.cmdQueue(), view);
}

fn dllStuff(buffer: MacOSOffscreenBuffer) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    if (lib_path) |path| {
        var cwd = try std.fs.cwd().openDir(".", .{});

        const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        const new_file_name = try std.fmt.allocPrint(allocator, "lib-{}.dylib", .{std.time.timestamp()});
        const tmp_path = try std.fs.path.join(allocator, &.{ exe_dir_path, new_file_name });

        const abs_lib_path = if (std.fs.path.isAbsolute(path)) path else try cwd.realpathAlloc(allocator, path);

        cwd.close();
        try std.fs.copyFileAbsolute(abs_lib_path, tmp_path, .{});

        var game_code = try GameCode.load(tmp_path);
        game_code.update_and_render_fn(buffer.bitmap.ToC(), 0);
        game_code.unload();

        try std.fs.deleteFileAbsolute(tmp_path);

        std.time.sleep(2 * 1_000_000_000);
    }
}
fn displayOffscreenBuffer(buffer: MacOSOffscreenBuffer, cmd_queue: Object, view: Object) void {
    buffer.texture.msgSend(void, "replaceRegion:mipmapLevel:withBytes:bytesPerRow:", .{
        ns.MTLRegion{
            .origin = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .size = .{
                .width = buffer.bitmap.width,
                .height = buffer.bitmap.height,
                .depth = 1,
            },
        },
        @as(u64, 0), // mipmap lvl
        buffer.bitmap.memory.ptr,
        buffer.bitmap.pitch(),
    });
    // std.debug.print("width: {}\nheight: {}\npitch: {}\nfirst_pixel = {any}\n", .{ buffer.bitmap.width, buffer.bitmap.height, buffer.bitmap.pitch(), buffer.bitmap.memory[0..4] });

    const drawable = view.msgSend(Object, "currentDrawable", .{});
    const to_texture = drawable.msgSend(Object, "texture", .{});

    const cmd_buffer: Object = cmd_queue.msgSend(Object, "commandBuffer", .{});
    const blt: Object = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});
    blt.msgSend(void, "copyFromTexture:toTexture:", .{
        buffer.texture,
        to_texture,
    });
    blt.msgSend(void, "endEncoding", .{});
    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable});
    cmd_buffer.msgSend(void, "commit", .{});
}
fn onResize(self_id: Id, _: objc.c.SEL, _: Id, size: ns.Size) callconv(.c) void {
    const self: Delegate = .{ .obj = .{ .value = self_id } };

    std.debug.print("changed size: {}, {}\n", .{
        @as(u32, @intFromFloat(size.width)),
        @as(u32, @intFromFloat(size.height)),
    });
    const runtime = self.getRuntime();
    runtime.offscreen_buffer.resize(
        self.device(),
        @intFromFloat(size.width),
        @intFromFloat(size.height),
    );
}
fn onShutdown(self_id: objc.c.id, _: objc.c.SEL, _: objc.c.id) callconv(.c) void {
    const self: Delegate = .{ .obj = .{ .value = self_id } };
    const runtime = self.getRuntime();
    _ = runtime;
}
fn shouldCloseAfterWindows(_: Id, _: objc.c.SEL) callconv(.c) bool {
    return true;
}

pub fn createDelegateClass() !objc.Class {
    const DelegateClass = objc.allocateClassPair(objc.getClass("NSObject"), "Delegate").?;

    if (!try DelegateClass.addMethod("drawInMTKView:", update)) {
        std.debug.print("failed to add app update\n", .{});
    }

    if (!try DelegateClass.addMethod("mtkView:drawableSizeWillChange:", onResize)) {
        std.debug.print("failed to add size change\n", .{});
    }

    if (!try DelegateClass.addMethod("applicationShouldTerminateAfterLastWindowClosed:", shouldCloseAfterWindows)) {
        std.debug.print("failed to add app quit\n", .{});
    }
    _ = try DelegateClass.addMethod("applicationWillTerminate:", onShutdown);

    if (!DelegateClass.addIvar("mtl_device")) {
        std.debug.print("failed to add mtl device\n", .{});
    }

    if (!DelegateClass.addIvar("mtl_cmd_queue")) {
        std.debug.print("failed to add mtl cmd queue\n", .{});
    }

    _ = objc.Sel.registerName("keyDown:");
    _ = try DelegateClass.addMethod("keyDown:", keyDown);

    if (!objc.c.class_addIvar(
        DelegateClass.value,
        "runtime",
        @sizeOf(*anyopaque),
        @alignOf(*anyopaque),
        "^v",
    )) {
        std.debug.print("failed to add struct\n", .{});
    }
    const AppProto = objc.getProtocol("NSApplicationDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, AppProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }

    const WndProto = objc.getProtocol("NSWindowDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, WndProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }

    const ViewProto = objc.getProtocol("MTKViewDelegate").?;
    if (!objc.c.class_addProtocol(DelegateClass.value, ViewProto.value)) {
        std.debug.print("failed to add app protocol\n\n", .{});
    }
    objc.registerClassPair(DelegateClass);

    const MTKViewSubclass = objc.allocateClassPair(objc.getClass("MTKView"), "MyMTKView").?;
    _ = try MTKViewSubclass.addMethod("acceptsFirstResponder", acceptsFirstResponder);
    _ = try MTKViewSubclass.addMethod("keyDown:", keyDown);
    objc.registerClassPair(MTKViewSubclass);

    return DelegateClass;
}
fn acceptsFirstResponder(_: objc.c.id, _: objc.c.SEL) callconv(.c) bool {
    return true;
}

pub fn device(self: Delegate) Object {
    return self.obj.getInstanceVariable("mtl_device");
}
pub fn cmdQueue(self: Delegate) Object {
    return self.obj.getInstanceVariable("mtl_cmd_queue");
}
pub fn getRuntime(self: Delegate) *Runtime {
    var tmp: ?*anyopaque = null;
    _ = objc.c.object_getInstanceVariable(self.obj.value, "runtime", @ptrCast(&tmp));
    return @alignCast(@ptrCast(tmp.?));
}
fn app() Object {
    const NSApplication: objc.Class = objc.getClass("NSApplication").?;
    return NSApplication.msgSend(Object, "sharedApplication", .{});
}

var r_was_pressed: bool = false;
fn keyDown(_: objc.c.id, _: objc.c.SEL, event_id: objc.c.id) callconv(.c) void {
    std.debug.print("key pressed\n", .{});
    const event: Object = .{ .value = event_id };
    const characters = event.msgSend(objc.Object, "characters", .{});
    const utf8_str = characters.msgSend([*:0]const u8, "UTF8String", .{});
    if (utf8_str[0] == 'r' or utf8_str[0] == 'R') {
        std.debug.print("r was pressed\n", .{});
        r_was_pressed = true;
    }
}
