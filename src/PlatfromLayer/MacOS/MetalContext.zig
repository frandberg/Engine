const std = @import("std");
const objc = @import("objc");

const common = @import("common");
const FramebufferPool = common.FramebufferPool;
const Framebuffer = common.Framebuffer;

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
backing_frame_buffers: Object,

pub fn init(backing_frame_buffer_mem: []const u32) MetalContext {
    const device = Object.fromId(MTLCreateSystemDefaultDevice());
    std.debug.assert(device.value != nil);

    const command_queue: Object = device.msgSend(
        Object,
        "newCommandQueue",
        .{},
    );
    std.debug.assert(command_queue.value != nil);

    const layer = objc.getClass("CAMetalLayer").?.msgSend(Object, "layer", .{});
    std.debug.assert(layer.value != nil);
    layer.msgSend(void, "setDevice:", .{device.value});

    const backing_frame_buffers = device.msgSend(
        Object,
        "newBufferWithBytesNoCopy:length:options:deallocator:",
        .{
            @as(*const anyopaque, backing_frame_buffer_mem.ptr),
            @as(usize, backing_frame_buffer_mem.len * FramebufferPool.bytes_per_pixel),
            @as(usize, 0), // MTLResourceStorageModeShared
            nil,
        },
    );
    std.debug.assert(backing_frame_buffers.value != nil);

    return .{
        .device = device,
        .command_queue = command_queue,
        .layer = layer,
        .backing_frame_buffers = backing_frame_buffers,
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

    blit(self.backing_frame_buffers, cmd_buffer, dst_texture, framebuffer_pool, framebuffer_index);

    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable.value});
    cmd_buffer.msgSend(void, "commit", .{});
    cmd_buffer.msgSend(void, "waitUntilCompleted", .{});
}

fn blit(
    mtl_buffer: Object,
    cmd_buffer: Object,
    dst_texture: Object,
    framebuffer_pool: *const FramebufferPool,
    framebuffer_index: usize,
) void {
    const framebuffer = framebuffer_pool.framebuffers[framebuffer_index];
    const blit_encoder: Object = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});

    blit_encoder.msgSend(void, "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", .{
        mtl_buffer,
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
