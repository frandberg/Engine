const std = @import("std");
const objc = @import("objc");

const common = @import("common");
const Framebuffer = common.Framebuffer;

const log = std.log.scoped(.MetalContext);

const CGSize = extern struct {
    width: f64,
    height: f64,
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
layer: Object,
frame_buffers: Object,

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

    const frame_buffers = device.msgSend(
        Object,
        "newBufferWithBytesNoCopy:length:options:deallocator:",
        .{
            @as(*const anyopaque, backing_frame_buffer_mem.ptr),
            @as(usize, backing_frame_buffer_mem.len * Framebuffer.bytes_per_pixel),
            @as(usize, 0), // MTLResourceStorageModeShared
            nil,
        },
    );
    std.debug.assert(frame_buffers.value != nil);

    return .{
        .device = device,
        .command_queue = command_queue,
        .layer = layer,
        .frame_buffers = frame_buffers,
    };
}

pub fn deinit(self: *MetalContext) void {
    self.command_queue.msgSend(void, "release", .{});
    self.layer.msgSend(void, "release", .{});
}

pub fn resizeLayer(self: *const MetalContext, width: u32, height: u32) void {
    self.layer.msgSend(void, "setDrawableSize:", .{
        CGSize{
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        },
    });
}

pub fn blitAndPresentFramebuffer(
    self: *const MetalContext,
    framebuffer: *const Framebuffer,
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
    const blit_encoder: Object = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});

    const base_ptr: usize = @intFromPtr(mtl_buffer.msgSend(*anyopaque, "contents", .{}));
    const offset: usize = @intFromPtr(framebuffer.memory.ptr) - base_ptr;
    std.debug.assert(!std.mem.allEqual(u32, framebuffer.memory, 0));

    // var count: usize = 0;
    // var values: []
    // for (framebuffer.memory) |pixel| {
    //     if (pixel != 0) {
    //         count += 1;
    //     }
    // }

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
