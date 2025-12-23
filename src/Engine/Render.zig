const std = @import("std");
const foundation = @import("foundation");
const Render = foundation.Render;
const math = @import("math");
const ecs = @import("ECS/ecs.zig");

pub const CommandBuffer = Render.CommandBuffer;
pub const ColorSprite = Render.ColorSprite;
pub const Camera = Render.Camera;

pub const Context = struct {
    cmd_buffer: *CommandBuffer,
};

const log = std.log.scoped(.Engine);

pub const Size = Render.Size;

pub fn renderColorSprites(world: *const ecs.World, cmd_buffer: *CommandBuffer) void {
    var iter = world.iterator(.encode(&.{
        .color_sprite,
        .transform,
    }));
    while (iter.next()) |entity_id| {
        const sprite = world.getComponent(.color_sprite, entity_id).?;
        const transform: math.Transform2D = world.getComponent(.transform, entity_id).?;

        cmd_buffer.push(.{
            .draw_color_sprite = .{
                .sprite = sprite,
                .transform = transform.mat3(),
            },
        });
    }
}
