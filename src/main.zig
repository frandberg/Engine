const macos_main = @import("MacOS/main.zig").main;
pub fn main() !void {
    try macos_main();
}
