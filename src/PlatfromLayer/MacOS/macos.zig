const std = @import("std");
const Application = @import("Application.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app: Application = undefined;
    try app.init(gpa.allocator(), 600, 400);
    defer app.deinit();

    try app.run();
}
