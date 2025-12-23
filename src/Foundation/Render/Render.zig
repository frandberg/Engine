pub const CommandBuffer = @import("CommandBuffer.zig");
pub const CommandBufferPool = @import("CommandBufferPool.zig");
pub const Camera = @import("Camera.zig");
const Sprite = @import("Sprite.zig");

pub const ColorSprite = Sprite.ColorSprite;

pub const Size = struct {
    width: u32,
    height: u32,
};

pub const Framebuffer = struct {
    handle: usize,
    size: Size,
};

pub const Frame = struct {
    framebuffer: ?Framebuffer,
    cmd_buffer: CommandBuffer,
};
