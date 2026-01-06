const std = @import("std");

const Allocator = std.mem.Allocator;

const FramebufferPool = @import("FramebufferPool.zig");
const Texture = @import("Texture.zig");
const Graphics = @import("../Graphics/Graphics.zig");

const PixelOrigin = Graphics.Target.PixelOrigin;

pub const Target = union(enum) {
    window: FramebufferPool,

    pub fn deinit(self: *Target, _: Allocator) void {
        switch (self.*) {
            .window => |*framebuffer_pool| framebuffer_pool.deinit(),
        }
    }

    pub fn acquire(self: *Target) ?Bound {
        return switch (self.*) {
            .window => |*framebuffer_pool| framebuffer_pool.acquire(),
        };
    }

    pub fn release(self: *Target, bound: Bound) void {
        switch (self.*) {
            .window => |*framebuffer_pool| {
                framebuffer_pool.publish(bound);
            },
        }
    }
};

pub const Bound = struct {
    texture: Texture,
    pixel_origin: PixelOrigin,
};
