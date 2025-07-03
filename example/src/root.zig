const std = @import("std");
const glue = @import("glue");

var frame: u32 = 0;
pub export fn updateAndRender(c_buffer: glue.c_OffscreenBuffer) void {
    const buffer = glue.OffscreenBuffer.fromC(c_buffer);
    const pixels: []u32 = @alignCast(std.mem.bytesAsSlice(u32, buffer.memory));
    for (pixels, 0..) |*pixel, pixel_index| {
        _ = pixel_index;
        // const x = pixel_index % buffer.width;
        // const y = @divFloor(pixel_index, buffer.height);
        // const red: u32 = 0;
        // const green: u32 = 0;
        // const blue: u32 = 0;
        // const alpha: u32 = 0;
        // pixel.* = blue | (green << 8) | (red << 16) | (alpha << 24);
        pixel.* = 0;
    }
    frame += 1;
}
