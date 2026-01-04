const std = @import("std");

const objc = @import("objc");
const core = @import("core");
const math = @import("math");

const Context = @import("Context.zig");

const c = @import("../c.zig").c;

const nil: objc.c.id = @ptrFromInt(0);

const log = std.log.scoped(.MetalRenderTarget);
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Atomic = std.atomic.Value;
const Renderer = core.SofwareRenderer;
const Grpahics = core.Graphics;
const Object = objc.Object;
const Class = objc.Class;
const AutoreleasePool = objc.AutoreleasePool;

const FramebufferPool = Renderer.FramebufferPool;
const Texture = Renderer.Texture;
const Sizeu = math.Sizeu;

const buffer_count = FramebufferPool.buffer_count;

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

const MetalSurface = @This();

frambuffers: Object,
layer: Object,

pub fn init(device: Object, framebuffer_pool: Renderer.FramebufferPool) MetalSurface {
    const layer_class: Class = objc.getClass("CAMetalLayer").?;
    const layer = layer_class.msgSend(Object, "layer", .{});
    assert(layer.value != nil);

    layer.msgSend(void, "setDevice:", .{device});

    const framebuffers = createFramebuffers(device, framebuffer_pool.backing_memory.bytes());

    return .{
        .frambuffers = framebuffers,
        .layer = layer,
    };
}

pub fn deinit(self: MetalSurface) void {
    self.frambuffers.msgSend(void, "release", .{});
    self.layer.msgSend(void, "release", .{});
}

pub fn needsResize(self: MetalSurface) ?Sizeu {
    const layer_size: Sizeu = blk: {
        const size = self.layer.msgSend(c.CGRect, "bounds", .{}).size;
        break :blk .{
            .width = @intFromFloat(size.width),
            .height = @intFromFloat(size.height),
        };
    };
    const drawable_size: Sizeu = blk: {
        const size = self.layer.msgSend(c.CGSize, "drawableSize", .{});
        break :blk .{
            .width = @intFromFloat(size.width),
            .height = @intFromFloat(size.height),
        };
    };
    // log.debug("Layer size: {}x{}, Drawable size: {}x{}: eql: {}", .{
    //     layer_size.width,
    //     layer_size.height,
    //     drawable_size.width,
    //     drawable_size.height,
    //     layer_size.eql(drawable_size),
    // });

    return if (!layer_size.eql(drawable_size)) layer_size else null;
}

pub fn recreate(
    self: *MetalSurface,
    device: Object,
    framebuffer_pool: Renderer.FramebufferPool,
) void {
    log.info("Recreating MetalSurface with size {}x{}", .{ framebuffer_pool.width, framebuffer_pool.height });
    const size: Sizeu = .{
        .width = framebuffer_pool.width,
        .height = framebuffer_pool.height,
    };

    self.frambuffers.msgSend(void, "release", .{});
    self.frambuffers = createFramebuffers(
        device,
        framebuffer_pool.backing_memory.bytes(),
    );
    self.setDrawableSize(size);
}

pub fn present(self: *MetalSurface, mtl_context: Context, framebuffer_pool: *FramebufferPool) void {
    const autorelease_pool = AutoreleasePool.init();
    defer autorelease_pool.deinit();

    const drawable = self.layer.msgSend(Object, "nextDrawable", .{});
    if (drawable.value == nil) {
        return;
    }

    const framebuffer = if (framebuffer_pool.consume()) |fb| fb else {
        //log.err("Failed to acquire framebuffer for presenting", .{});
        return;
    };
    defer framebuffer_pool.release(framebuffer);

    if (self.isOutOfDate(framebuffer_pool)) {
        framebuffer_pool.consumeResize();
        self.recreate(mtl_context.device, framebuffer_pool.*);
    }

    const dst_texture: Object = drawable.msgSend(
        Object,
        "texture",
        .{},
    );

    const cmd_buffer: Object = mtl_context.command_queue.msgSend(
        Object,
        "commandBuffer",
        .{},
    );

    blit(self.frambuffers, cmd_buffer, dst_texture, framebuffer);

    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable.value});
    cmd_buffer.msgSend(void, "commit", .{});
    cmd_buffer.msgSend(void, "waitUntilCompleted", .{});
}

fn blit(
    mtl_buffer: Object,
    cmd_buffer: Object,
    dst_texture: Object,
    framebuffer: Texture,
) void {
    const offset = calculateOffset(mtl_buffer, framebuffer);
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
//TODO take in a format also and derivce bytes per pixel from there instead of hard coded
fn createFramebuffers(device: Object, framebuffers_backing_mem: []const u8) Object {
    const framebuffers = device.msgSend(
        Object,
        "newBufferWithBytesNoCopy:length:options:deallocator:",
        .{
            @as(*const anyopaque, framebuffers_backing_mem.ptr),
            @as(usize, framebuffers_backing_mem.len),
            @as(usize, 0), // MTLResourceStorageModeShared
            nil,
        },
    );
    assert(framebuffers.value != nil);
    return framebuffers;
}

fn calculateOffset(mtl_buffer: Object, framebuffer: Texture) usize {
    const base_ptr: *anyopaque = mtl_buffer.msgSend(*anyopaque, "contents", .{});
    const src_ptr: *anyopaque = framebuffer.memory.bytes().ptr;

    const base_int: usize = @intFromPtr(base_ptr);
    const src_int: usize = @intFromPtr(src_ptr);

    const offset: usize = src_int - base_int;

    const buf_len: usize = mtl_buffer.msgSend(usize, "length", .{});

    if (src_int - base_int + framebuffer.size() >= buf_len) {
        log.err("ptrs wrong: base_ptr: {*} src_ptr: {*}, offset: {}, buffer_lenght: {}, texture_width: {}, texture_height: {}", .{
            base_ptr,
            src_ptr,
            offset,
            buf_len,
            framebuffer.width,
            framebuffer.height,
        });
    }

    assert(src_int >= base_int);
    assert((src_int - base_int) + framebuffer.size() <= buf_len);

    return offset;
}

fn isOutOfDate(self: *const MetalSurface, framebuffer_pool: *const FramebufferPool) bool {
    const lenght = self.frambuffers.msgSend(usize, "length", .{});
    if (lenght != framebuffer_pool.backing_memory.bytes().len) {
        return true;
    }

    const drawable_size = self.drawableSize();
    const fb_size: Sizeu = .{
        .width = framebuffer_pool.width,
        .height = framebuffer_pool.height,
    };
    if (!drawable_size.eql(fb_size)) {
        return true;
    }
    return false;
}

fn drawableSize(self: *const MetalSurface) Sizeu {
    const size = self.layer.msgSend(c.CGSize, "drawableSize", .{});
    return .{
        .width = @intFromFloat(size.width),
        .height = @intFromFloat(size.height),
    };
}

fn setDrawableSize(self: *const MetalSurface, size: Sizeu) void {
    const cg_size = c.CGSize{
        .width = @floatFromInt(size.width),
        .height = @floatFromInt(size.height),
    };
    self.layer.msgSend(void, "setDrawableSize:", .{cg_size});
}

fn layerSize(self: *const MetalSurface) Sizeu {
    const size = self.layer.msgSend(c.CGRect, "bounds", .{}).size;
    return .{
        .width = @intFromFloat(size.width),
        .height = @intFromFloat(size.height),
    };
}
