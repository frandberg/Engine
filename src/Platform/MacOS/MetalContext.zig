const std = @import("std");
const objc = @import("objc");

const foundation = @import("foundation");

const Framebuffer = foundation.SofwareRenderer.Framebuffer;
const log = std.log.scoped(.MetalContext);

const c = @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
});

const CGSize = extern struct {
    width: f64,
    height: f64,
};

const Size = struct {
    width: u32,
    height: u32,
};

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

extern fn MTLCreateSystemDefaultDevice() objc.c.id;

const MetalContext = @This();

const MTLSize = extern struct {
    width: usize,
    height: usize,
    depth: usize,
};

const MTLOrigin = extern struct {
    x: usize,
    y: usize,
    z: usize,
};

device: Object,
command_queue: Object,
view: Object,
layer: Object,
frame_buffers: Object,
need_resize: ?Size = null,

pub fn init(backing_frame_buffer_mem: []const u32, view: Object) MetalContext {
    const device = Object.fromId(MTLCreateSystemDefaultDevice());
    std.debug.assert(device.value != nil);

    const command_queue: Object = device.msgSend(
        Object,
        "newCommandQueue",
        .{},
    );
    std.debug.assert(command_queue.value != nil);

    const CAMetalLayer = objc.getClass("CAMetalLayer").?;
    const layer = CAMetalLayer.msgSend(Object, "layer", .{});

    view.msgSend(void, "setWantsLayer:", .{true});
    view.msgSend(void, "setLayer:", .{layer.value});

    layer.msgSend(void, "setDevice:", .{device.value});

    const frame_buffers = createFrameBuffers(device, backing_frame_buffer_mem);

    return .{
        .device = device,
        .command_queue = command_queue,
        .view = view,
        .layer = layer,
        .frame_buffers = frame_buffers,
    };
}

pub fn deinit(self: *const MetalContext) void {
    self.command_queue.msgSend(void, "release", .{});
    self.layer.msgSend(void, "release", .{});
}

pub fn recreateFramebuffers(self: *MetalContext, backing_frame_buffer_mem: []const u32, width: u32, height: u32) void {
    self.frame_buffers.msgSend(void, "release", .{});
    self.frame_buffers = createFrameBuffers(self.device, backing_frame_buffer_mem);
    self.resizeLayer(width, height);
}

fn createFrameBuffers(device: Object, backing_memory: []const u32) objc.Object {
    const frame_buffers = device.msgSend(
        Object,
        "newBufferWithBytesNoCopy:length:options:deallocator:",
        .{
            @as(*const anyopaque, backing_memory.ptr),
            @as(usize, backing_memory.len * Framebuffer.bytes_per_pixel),
            @as(usize, 0), // MTLResourceStorageModeShared
            nil,
        },
    );
    std.debug.assert(frame_buffers.value != nil);
    return frame_buffers;
}
fn resizeLayer(self: *const MetalContext, width: u32, height: u32) void {
    self.layer.msgSend(void, "setDrawableSize:", .{
        CGSize{
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        },
    });
}

pub fn blitAndPresentFramebuffer(
    self: *MetalContext,
    framebuffer: *const Framebuffer,
) void {
    const autoreleaspool = objc.AutoreleasePool.init();
    defer autoreleaspool.deinit();

    const drawable = self.layer.msgSend(Object, "nextDrawable", .{});
    if (drawable.value == nil) {
        return;
    }

    const view_size: c.CGSize = self.view.msgSend(c.CGRect, "bounds", .{}).size;
    const view_width: usize = @intFromFloat(view_size.width);
    const view_height: usize = @intFromFloat(view_size.height);

    const dst_texture: Object = drawable.msgSend(
        Object,
        "texture",
        .{},
    );

    const dst_w = dst_texture.msgSend(usize, "width", .{});
    const dst_h = dst_texture.msgSend(usize, "height", .{});

    if (dst_w != view_width or dst_h != view_height) {
        std.debug.print(
            "view size changed from : {}x{}, texture size is {}x{}",
            .{ view_width, view_height, dst_w, dst_h },
        );
        self.need_resize = .{
            .width = @intCast(view_width),
            .height = @intCast(view_height),
        };
        return;
    }

    const cmd_buffer: Object = self.command_queue.msgSend(
        Object,
        "commandBuffer",
        .{},
    );

    blit(
        self.frame_buffers,
        cmd_buffer,
        dst_texture,
        framebuffer,
    );

    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable.value});
    cmd_buffer.msgSend(void, "commit", .{});
    cmd_buffer.msgSend(void, "waitUntilCompleted", .{});
}

fn blit(
    mtl_buffer: Object,
    cmd_buffer: Object,
    dst_texture: Object,
    framebuffer: *const Framebuffer,
) void {
    const base_ptr: usize = @intFromPtr(mtl_buffer.msgSend(*anyopaque, "contents", .{}));
    const offset: usize = @intFromPtr(framebuffer.memory.ptr) - base_ptr;

    const buf_len: usize = mtl_buffer.msgSend(usize, "length", .{});
    const src_ptr: usize = @intFromPtr(framebuffer.memory.ptr);
    std.debug.assert(src_ptr >= base_ptr);
    std.debug.assert((src_ptr - base_ptr) + framebuffer.size() <= buf_len);

    std.debug.assert(src_ptr >= base_ptr);
    std.debug.assert((src_ptr - base_ptr) + framebuffer.size() <= buf_len);

    const blit_encoder: Object = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});

    blit_encoder.msgSend(void, "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", .{
        mtl_buffer,
        offset,
        framebuffer.pitch(),
        framebuffer.size(),
        MTLSize{
            .width = framebuffer.width,
            .height = framebuffer.height,
            .depth = 1,
        },
        dst_texture,
        @as(usize, 0),
        @as(usize, 0),
        MTLOrigin{
            .x = 0,
            .y = 0,
            .z = 0,
        },
    });

    blit_encoder.msgSend(void, "endEncoding", .{});
}
