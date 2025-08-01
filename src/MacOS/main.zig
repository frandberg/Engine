const std = @import("std");

const Application = @import("Application.zig");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();

    var application: Application = undefined;
    try application.init(gpa_state.allocator(), 800, 600);

    defer application.deinit();
    application.run();
}
