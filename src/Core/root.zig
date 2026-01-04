pub const Input = @import("Input/Input.zig");
pub const Graphics = @import("Graphics/Graphics.zig");
pub const SofwareRenderer = @import("SoftwareRenderer/Renderer.zig");

pub const Game = @import("Game.zig");

pub const WindowSpec = struct {
    width: u32,
    height: u32,
    title: []const u8,

    pub const default: WindowSpec = .{
        .width = 800,
        .height = 600,
        .title = "Game",
    };
};

pub const LocalWindowedAppSpec = struct {
    window: WindowSpec,
    update_hz: f32,
};
