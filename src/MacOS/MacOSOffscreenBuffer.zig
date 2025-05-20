const std = @import("std");
const glue = @import("glue");
const objc = @import("objc");
const ns = @import("Cocoa.zig");
const Object = objc.Object;

const Self = @This();

allocator: std.mem.Allocator,
bitmap: glue.OffscreenBuffer,
texture: Object,

pub fn init(allocator: std.mem.Allocator, device: Object, width: u32, height: u32) Self {
    return .{
        .allocator = allocator,
        .bitmap = .{
            .memory = allocator.alloc(u8, width * height * glue.OffscreenBuffer.bytes_per_pixel) catch @panic("OOM"),
            .width = width,
            .height = height,
        },
        .texture = createTexture(device, width, height),
    };
}

pub fn resize(self: *Self, device: Object, width: u32, height: u32) void {
    self.allocator.free(self.bitmap.memory);
    self.texture.msgSend(void, "release", .{});

    self.* = init(self.allocator, device, width, height);
}
fn createTexture(device: Object, width: u32, height: u32) Object {
    const TextureDescClass = objc.getClass("MTLTextureDescriptor").?;
    const descriptor = TextureDescClass.msgSend(
        Object,
        "texture2DDescriptorWithPixelFormat:width:height:mipmapped:",
        .{
            @intFromEnum(ns.MTLPixelFormat.BGRA8Unorm),
            width,
            height,
            0,
        },
    );
    descriptor.setProperty("mipmapLevelCount", @as(i64, 1));
    return device.msgSend(Object, "newTextureWithDescriptor:", .{descriptor});
}
