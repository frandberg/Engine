const std = @import("std");
pub const c_OffscreenBuffer = extern struct {
    memory: [*]u8,
    width: u32,
    height: u32,
};

pub const UpdateAndRenderFn = fn (ofscreen_buffer: c_OffscreenBuffer, time_step: f64) callconv(.c) void;

fn c_OffscreenBufferSize(buffer: c_OffscreenBuffer) u32 {
    return buffer.width * buffer.height * OffscreenBuffer.elements_per_pixel * ((OffscreenBuffer.bits_per_element + 7) / 8);
}

pub const OffscreenBuffer = struct {
    pub const bits_per_element = 8;
    pub const elements_per_pixel = 4;
    pub const bytes_per_pixel = elements_per_pixel * ((bits_per_element + 7) / 8);

    memory: []u8,
    width: u32,
    height: u32,

    pub fn fromC(c_buffer: c_OffscreenBuffer) OffscreenBuffer {
        return .{
            .memory = c_buffer.memory[0..c_OffscreenBufferSize(c_buffer)],
            .width = c_buffer.width,
            .height = c_buffer.height,
        };
    }

    pub fn ToC(self: OffscreenBuffer) c_OffscreenBuffer {
        return .{
            .memory = self.memory.ptr,
            .width = self.width,
            .height = self.height,
        };
    }

    pub fn size(self: OffscreenBuffer) u32 {
        return self.width * self.height * bytes_per_pixel;
    }

    pub fn pitch(self: OffscreenBuffer) u32 {
        return self.width * bytes_per_pixel;
    }
};

pub fn updateAndRenderStub(c_buffer: c_OffscreenBuffer, _: f64) callconv(.c) void {
    const buffer = OffscreenBuffer.fromC(c_buffer);
    @memset(buffer.memory, 0);
    const memory: []u32 = @alignCast(std.mem.bytesAsSlice(u32, buffer.memory));
    const magenta: u32 = (255 | (255 << 16));
    @memset(memory, magenta);
}
