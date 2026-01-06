const std = @import("std");
const Commands = @import("Commands.zig");
pub const Command = Commands.Command;
pub const CommandBuffer = Commands.CommandBuffer;

pub const Camera = @import("Camera.zig");
pub const Sprite = @import("Sprite.zig");
const math = @import("math");

pub const ColorSprite = Sprite.ColorSprite;

pub const Context = struct { cmd_buffer: CommandBuffer };
pub const RenderFn = fn (game: *anyopaque, render_ctx: Context) void;

pub const Target = struct {
    pub const Handle = u32;
    pub const Spec = struct {
        format: Format,
        pixel_origin: PixelOrigin,
        width: u32,
        height: u32,
    };

    pub const PixelOrigin = enum {
        top_left,
        bottom_left,
    };
};

pub const Format = enum {
    bgra8_u,

    pub fn bytesPerPixel(self: Format) u32 {
        return switch (self) {
            inline else => @sizeOf(BackingType(self)),
        };
    }

    pub fn BackingType(comptime self: Format) type {
        return switch (self) {
            .bgra8_u => u32,
        };
    }

    pub fn pixel(comptime self: Format, color: math.Color) BackingType(self) {
        const clamp = std.math.clamp;
        return switch (self) {
            .bgra8_u => blk: {
                const b: u32 = @intFromFloat(clamp(color.b, 0, 1) * 255);
                const g: u32 = @intFromFloat(clamp(color.g, 0, 1) * 255);
                const r: u32 = @intFromFloat(clamp(color.r, 0, 1) * 255);
                const a: u32 = @intFromFloat(clamp(color.a, 0, 1) * 255);

                break :blk b | g << 8 | r << 16 | a << 24;
            },
        };
    }
};

pub const RendererSpec = struct {
    render_fn: RenderFn,
};

pub const ViewSpec = struct {
    camera: Camera,
    viewport: math.Rect,
    target: Target.Handle,
};
