const std = @import("std");
const objc = @import("objc");

const FramebufferPool = @import("FramebufferPool.zig");
const Framebuffer = FramebufferPool.Framebuffer;

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
layer: Object,

pub fn init() MetalContext {
    const device = Object.fromId(MTLCreateSystemDefaultDevice());
    std.debug.assert(device.value != nil);

    const command_queue: Object = device.msgSend(
        Object,
        "newCommandQueue",
        .{},
    );
    const layer = objc.getClass("CAMetalLayer").?.msgSend(Object, "layer", .{});
    layer.msgSend(void, "setDevice:", .{device.value});
    return .{
        .device = device,
        .command_queue = command_queue,
        .layer = layer,
    };
}

pub fn deinit(self: *MetalContext) void {
    self.command_queue.msgSend(void, "release", .{});
    self.layer.msgSend(void, "release", .{});
}

pub fn blitAndPresentFramebuffer(
    self: *const MetalContext,
    framebuffer_pool: *const FramebufferPool,
    framebuffer_index: usize,
) void {
    const drawable = self.layer.msgSend(Object, "nextDrawable", .{});
    if (drawable.value == nil) {
        return;
    }

    const cmd_buffer: Object = self.command_queue.msgSend(
        Object,
        "commandBuffer",
        .{},
    );

    const dst_texture: Object = drawable.msgSend(
        Object,
        "texture",
        .{},
    );

    blit(cmd_buffer, dst_texture, framebuffer_pool, framebuffer_index);

    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable.value});
    cmd_buffer.msgSend(void, "commit", .{});
    cmd_buffer.msgSend(void, "waitUntilCompleted", .{});
}

fn blit(
    cmd_buffer: Object,
    dst_texture: Object,
    framebuffer_pool: *const FramebufferPool,
    framebuffer_index: usize,
) void {
    const framebuffer = framebuffer_pool.framebuffers[framebuffer_index];
    const blit_encoder: Object = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});
    blit_encoder.msgSend(void, "synchronizeResource:", .{framebuffer_pool.mtl_buffer.value});

    blit_encoder.msgSend(void, "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", .{
        framebuffer_pool.mtl_buffer.value,
        framebuffer_pool.bufferOffset(framebuffer_index),
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
