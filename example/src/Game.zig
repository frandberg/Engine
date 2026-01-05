const std = @import("std");
const Engine = @import("Engine");

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.game);

const Graphics = Engine.Graphics;
const ecs = Engine.ecs;
const math = Engine.math;

const TargetHandle = Graphics.Target.Handle;
const World = ecs.World;
const EntityID = ecs.EntityID;
const CommandBuffer = Graphics.CommandBuffer;
const ColorSprite = Graphics.ColorSprite;
const Transform2D = math.Transform2D;
const Color = math.Color;

const white: Color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
const black: Color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };

const Game = @This();

gpa: Allocator,

entity: ecs.EntityID,
world: Engine.ecs.World,
camera: Graphics.Camera,
window_target: TargetHandle,

pub fn init(gpa: Allocator, window_target: TargetHandle) Game {
    var world = World.init(gpa, 50);
    const sprite: ColorSprite = .{
        .color = white,
        .extents = .{
            .half_width = 1.0,
            .half_height = 1.0,
        },
    };
    const transform: Transform2D = .{
        .translation = .{ .x = 0, .y = 0 },
        .rotation = 0.788,

        .scale = .{ .x = 1.0, .y = 1.0 },
    };

    const entity = world.createEntity(&.{
        .{ .color_sprite = sprite },
        .{ .transform = transform },
    }).?;

    const camera_transform: Transform2D = .{
        .translation = .{ .x = 0.0, .y = 0.0 },
        .rotation = 0.0,
        .scale = .{ .x = 1.0, .y = 1.0 },
    };
    const camera: Graphics.Camera = .{
        .transform = camera_transform,
        .kind = .{ .orthographic = .{
            .height = 10.0,
        } },
        .near = -1.0,
        .far = 1.0,
    };

    return .{
        .gpa = gpa,
        .world = world,
        .entity = entity,
        .camera = camera,
        .window_target = window_target,
    };
}

pub fn deinit(self: *Game) void {
    self.world.deinit();
}
var frame_index: usize = 0;
pub fn update(self: *Game, time_step_seconds: f64) void {
    const entity = self.entity;
    const ts: f32 = @floatCast(time_step_seconds);

    const transform: *Transform2D = self.world.getComponentPtr(.transform, entity).?;

    const rotation_speed = 1.0;
    if (frame_index % 1 == 0) {
        transform.rotation += rotation_speed * ts;
    }
    frame_index += 1;
}

pub fn render(self: *const Game, command_buffer: Engine.Graphics.CommandBuffer) void {
    command_buffer.push(.{ .clear = .{
        .color = black,
        .target = self.window_target,
    } });

    const entity = self.entity;

    const sprite = self.world.getComponent(.color_sprite, entity).?;
    const transform = self.world.getComponent(.transform, entity).?;

    command_buffer.push(.{
        .set_view = .{
            .target = self.window_target,
            .camera = self.camera,
            .viewport = .{
                .x = 0,
                .y = 0,
                .width = 1.0,
                .height = 1.0,
            },
        },
    });

    command_buffer.push(.{ .draw = .{
        .color_sprite = .{
            .sprite = sprite,
            .transform = transform.mat3(),
        },
    } });
}
