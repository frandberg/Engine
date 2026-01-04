const std = @import("std");

const Allocator = std.mem.Allocator;

const FramebufferPool = @import("FramebufferPool.zig");
const Texture = @import("Texture.zig");

pub const Target = union(enum) {
    window: FramebufferPool,

    pub fn deinit(self: *Target, allocator: Allocator) void {
        switch (self.*) {
            .window => |*framebuffer_pool| framebuffer_pool.deinit(allocator),
        }
    }

    pub fn acquire(self: *Target) ?Texture {
        return switch (self.*) {
            .window => |*framebuffer_pool| framebuffer_pool.acquire(),
        };
    }

    pub fn release(self: *Target, bound: Texture) void {
        switch (self.*) {
            .window => |*framebuffer_pool| {
                framebuffer_pool.publish(bound);
            },
        }
    }
};
