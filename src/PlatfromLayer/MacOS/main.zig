const std = @import("std");

const Application = @import("Application.zig");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();

    var application = try Application.init(allocator, 800, 600);
    defer application.deinit(allocator);

    try application.run();
}
