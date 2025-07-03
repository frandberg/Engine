const std = @import("std");
const ns = @import("Cocoa.zig");
const objc = @import("objc");
const Object = objc.Object;
const glue = @import("glue");

pub const Origin = extern struct {
    x: u64,
    y: u64,
    z: u64,
};

pub const Size = extern struct {
    width: u64,
    height: u64,
    depth: u64,
};

pub const Region = extern struct {
    origin: Origin,
    size: Size,
};
pub const PixelFormat = enum(usize) {
    Invalid = 0,
    A8Unorm = 1,
    R8Unorm = 10,
    R8Uint = 11,
    R8Sint = 12,
    R16Unorm = 20,
    R16Float = 22,
    RG8Unorm = 30,
    RG8Uint = 31,
    B5G6R5Unorm = 40,
    RGBA8Unorm = 70,
    RGBA8Unorm_sRGB = 71,
    RGBA8Uint = 73,
    BGRA8Unorm = 80,
    BGRA8Unorm_sRGB = 81,
    RGB10A2Unorm = 90,
    RG11B10Float = 92,
    RGB9E5Float = 93,
    BGR10A2Unorm = 94,
    RGBA16Float = 112,
    RGBA32Float = 123,

    // Depth/stencil
    Depth32Float = 252,
    Stencil8 = 253,
    Depth32Float_Stencil8 = 255,
};

extern fn MTLCreateSystemDefaultDevice() objc.c.id;

pub const Context = struct {
    device: Object,
    cmd_queue: Object,
    layer: Object,

    pub fn init() Context {
        const CAMetalLayerClass = objc.getClass("CAMetalLayer").?;

        const device: Object = .{ .value = MTLCreateSystemDefaultDevice() };
        const cmd_queue: Object = device.msgSend(Object, "newCommandQueue", .{});
        const layer = CAMetalLayerClass.msgSend(Object, "alloc", .{}).msgSend(Object, "init", .{});
        layer.msgSend(void, "setDevice:", .{device});
        layer.msgSend(void, "setMaximumDrawableCount:", .{@as(ns.UInteger, 3)});
        layer.msgSend(void, "setPresentsWithTransaction:", .{false});

        return .{
            .device = device,
            .cmd_queue = cmd_queue,
            .layer = layer,
        };
    }
    pub fn presentTexture(self: Context, texture: Texture) void {
        const cmd_buffer = self.cmd_queue.msgSend(Object, "commandBuffer", .{});

        const drawable = self.layer.msgSend(Object, "nextDrawable", .{});
        std.debug.assert(@as(usize, @intFromPtr(drawable.value)) != 0);

        const drawable_texture = drawable.msgSend(Object, "texture", .{});
        const blit_encoder = cmd_buffer.msgSend(Object, "blitCommandEncoder", .{});

        blit_encoder.msgSend(void, "copyFromTexture:toTexture:", .{
            texture.object,
            drawable_texture,
        });

        blit_encoder.msgSend(void, "endEncoding", .{});
        cmd_buffer.msgSend(void, "presentDrawable:", .{drawable});
        cmd_buffer.msgSend(void, "commit", .{});
    }
};

pub const Texture = struct {
    object: Object,

    pub fn create(device: Object, width: u32, height: u32) Texture {
        const MTLTextureDescriptorClass = objc.getClass("MTLTextureDescriptor").?;

        const descriptor = MTLTextureDescriptorClass.msgSend(Object, "texture2DDescriptorWithPixelFormat:width:height:mipmapped:", .{
            PixelFormat.BGRA8Unorm,
            @as(ns.UInteger, width),
            @as(ns.UInteger, height),
            false,
        });

        const object = device.msgSend(Object, "newTextureWithDescriptor:", .{descriptor});
        return .{
            .object = object,
        };
    }

    pub fn destroy(self: Texture) void {
        self.object.msgSend(void, "release", .{});
    }

    // pub fn width(self: Texture) ns.UInteger {
    //     return self.object.msgSend(ns.UInteger, "width", .{});
    // }
    // pub fn height(self: Texture) ns.UInteger {
    //     return self.object.msgSend(ns.UInteger, "height", .{});
    // }
    pub fn uploadBufferData(self: Texture, buffer: glue.OffscreenBuffer) void {
        const region = Region{
            .origin = .{
                .x = 0,
                .y = 0,
                .z = 0,
            },
            .size = .{
                .width = buffer.width,
                .height = buffer.height,
                .depth = 1,
            },
        };

        std.debug.assert(self.object.msgSend(ns.UInteger, "width", .{}) >= buffer.width);
        std.debug.assert(self.object.msgSend(ns.UInteger, "height", .{}) >= buffer.height);

        self.object.msgSend(void, "replaceRegion:mipmapLevel:withBytes:bytesPerRow:", .{
            region,
            @as(ns.UInteger, 0),
            buffer.memory.ptr,
            @as(ns.UInteger, buffer.pitch()),
        });
    }
};
