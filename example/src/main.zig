const std = @import("std");
const Engine = @import("Engine");

const log = std.log.scoped(.Game);
const Allocator = std.mem.Allocator;
const DebugAllocator = std.heap.DebugAllocator(.{});
const CommandBuffer = Engine.Render.CommandBuffer;
const ColorSprite = Engine.Render.ColorSprite;
const Input = Engine.Input;
const Transform2D = Engine.math.Transform2D;
const World = Engine.ecs.World;
const EntityID = Engine.ecs.EntityID;
const Render = Engine.Render;
const FrameContext = Engine.FrameContext;

const math = Engine.math;

const ecs = Engine.ecs;

const FixesBufferAllocator = std.heap.FixedBufferAllocator;

const Game = struct {
    gpa: Allocator,
    entity: ecs.EntityID,
    world: Engine.ecs.World,

    fn init(gpa: Allocator) Game {
        var world = World.init(gpa, 50);

        const sprite: ColorSprite = .{
            .color = white,
            .extents = .{
                .half_width = 0.5,
                .half_height = 0.5,
            },
        };
        const transform: Transform2D = .{
            .translation = .{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .scale = .{ .x = 1.0, .y = 1.0 },
        };

        const entity = world.createEntity(&.{
            .{ .color_sprite = sprite },
            .{ .transform = transform },
        }).?;

        return .{
            .gpa = gpa,
            .world = world,
            .entity = entity,
        };
    }

    fn deinit(self: *Game) void {
        self.world.deinit();
    }
};

pub fn main() !void {
    var gpa: DebugAllocator = .{};
    defer _ = gpa.deinit();

    const code = Engine.Game.Code.makeWrapper(
        Game,
        updateAndRender,
    );

    const config: Engine.Game.Config = .{
        .code = code,
        .update_hz = 30.0,
    };

    var game = Game.init(gpa.allocator());
    defer game.deinit();

    var engine: Engine = undefined;
    try engine.init(gpa.allocator(), &game, config);
    defer engine.deinit(gpa.allocator());

    try engine.run();
}

const black = math.Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
const white = math.Color{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };

fn updateAndRender(
    game: *Game,
    _: Allocator,
    render_ctx: Render.Context,
    //input: Input,
    time_step: f64,
) void {
    const transform: *Transform2D = game.world.getComponentPtr(.transform, game.entity).?;
    const cmd_buffer = render_ctx.cmd_buffer;

    transform.rotation += @floatCast(0.5 * time_step);

    const camera: Engine.Render.Camera = .{
        .transform = .{
            .translation = .{ .x = 0.0, .y = 0.0 },
            .rotation = 0.0,
            .scale = .{ .x = 1.0, .y = 1.0 },
        },
        .kind = .{
            .orthographic = .{
                .height = 2.0,
            },
        },
        .far = 1.0,
        .near = -1.0,
    };

    cmd_buffer.push(.{ .clear = black });
    cmd_buffer.push(.{
        .set_view = .{
            .camera = camera,
            .viewport = .{
                .x = 0.0,
                .y = 0.0,
                .width = 1.0,
                .height = 1.0,
            },
        },
    });

    Render.renderColorSprites(
        &game.world,
        cmd_buffer,
    );
}
