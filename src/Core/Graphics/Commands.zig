const std = @import("std");
const Sprite = @import("Sprite.zig");

const math = @import("math");
const Color = math.Color;
const ColorSprite = Sprite.ColorSprite;
const Transform2D = math.Transform2D;
const Camera = @import("Camera.zig");

const Graphics = @import("Graphics.zig");

const log = std.log.scoped(.command_recorder);

pub const CommandBuffer = struct {
    ptr: *anyopaque,
    vtab: *const VTab,

    pub const VTab = struct {
        push: *const fn (ptr: *anyopaque, command: Command) void,
    };

    pub fn push(self: CommandBuffer, command: Command) void {
        self.vtab.push(self.ptr, command);
    }
};

pub const Command = union(enum) {
    set_view: Graphics.ViewSpec,
    draw: Draw,
    clear: Clear,

    pub const Draw = union(enum) {
        color_sprite: DrawColorSprite,
        pub const DrawColorSprite = struct {
            sprite: ColorSprite,
            transform: math.Mat3f,
        };
    };

    pub const Clear = struct {
        color: Color,
        target: Graphics.Target.Handle,
    };
};
