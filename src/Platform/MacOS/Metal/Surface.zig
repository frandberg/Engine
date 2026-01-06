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

var frame_index: usize = 0;
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

    if (frame_index == 0) {
        const file = std.fs.cwd().createFile("broken_quad.bmp", .{}) catch @panic("file open failed");
        defer file.close();
        var writer_buffer: [4096]u8 = undefined;
        var writer = file.writer(&writer_buffer);

        const texture = framebuffer.texture;

        const pixels: []const u8 = @alignCast(std.mem.sliceAsBytes(texture.raw(.bgra8_u).memory));

        writeBmp(&writer.interface, pixels, @intCast(texture.width), @intCast(texture.height), texture.pitch()) catch @panic("failed to write bmp");
    }

    blit(self.frambuffers, cmd_buffer, dst_texture, framebuffer.texture);

    cmd_buffer.msgSend(void, "presentDrawable:", .{drawable.value});
    cmd_buffer.msgSend(void, "commit", .{});
    cmd_buffer.msgSend(void, "waitUntilCompleted", .{});
    frame_index += 1;
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

fn writeBmp(
    writer: *std.Io.Writer,
    pixels: []const u8, // BGRA8
    width: i32,
    height: i32,
    pitch: usize,
) !void {
    const header_size: u32 = 14 + 40;
    const image_size: u32 = @intCast(width * height * 4);
    const file_size: u32 = header_size + image_size;

    // -------------------------------------------------
    // BITMAPFILEHEADER (14 bytes)
    // -------------------------------------------------

    try writer.writeByte('B');
    try writer.writeByte('M');
    try writer.writeInt(u32, file_size, .little);
    try writer.writeInt(u16, 0, .little);
    try writer.writeInt(u16, 0, .little);
    try writer.writeInt(u32, header_size, .little);

    // -------------------------------------------------
    // BITMAPINFOHEADER (40 bytes)
    // -------------------------------------------------
    try writer.writeInt(u32, 40, .little); // biSize
    try writer.writeInt(i32, width, .little);
    try writer.writeInt(i32, -height, .little); // top-down
    try writer.writeInt(u16, 1, .little); // planes
    try writer.writeInt(u16, 32, .little); // bitcount
    try writer.writeInt(u32, 0, .little); // BI_RGB
    try writer.writeInt(u32, image_size, .little);
    try writer.writeInt(i32, 0, .little); // X ppm
    try writer.writeInt(i32, 0, .little); // Y ppm
    try writer.writeInt(u32, 0, .little); // clr used
    try writer.writeInt(u32, 0, .little); // clr important

    // -------------------------------------------------
    // Pixel data
    // -------------------------------------------------
    const row_bytes: usize = @intCast(width * 4);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const src = y * pitch;
        try writer.writeAll(pixels[src .. src + row_bytes]);
    }
}
