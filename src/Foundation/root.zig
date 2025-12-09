pub const Input = @import("Input.zig");
pub const Render = @import("Render/Render.zig");
pub const SofwareRenderer = @import("SoftwareRenderer/Renderer.zig");

pub const WindowInfo = struct {
    width: u32,
    height: u32,
};

pub const PlatformInfo = struct {
    window_info: WindowInfo,
};
