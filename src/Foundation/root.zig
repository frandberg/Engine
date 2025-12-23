pub const Input = @import("Input/Input.zig");
pub const Render = @import("Render/Render.zig");
pub const SofwareRenderer = @import("Render/SoftwareRenderer/Renderer.zig");

pub const WindowInfo = struct {
    width: u32,
    height: u32,
    title: []const u8,
};

pub const PlatformInfo = struct {
    window_info: WindowInfo,
};
