const std = @import("std");

const Args = @This();

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

game_lib: ?[]const u8 = null,

pub fn get() Args {
    var args: Args = .{};
    var arg_iter = std.process.args();

    while (arg_iter.next()) |arg| {
        if (eql("-g", arg) or eql("--game-lib", arg)) {
            const game_lib = arg_iter.next();
            if (game_lib) |lib| {
                if (lib.len > 0) {
                    args.game_lib = game_lib;
                }
            }
        }
    }
    return args;
}
