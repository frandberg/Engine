const std = @import("std");
const Texture = @This();
const math = @import("math");

const Graphics = @import("../Graphics/Graphics.zig");
const Format = Graphics.Format;

pub const Memory = union(Format) {
    bgra8_u: []u32,

    pub fn getFormat(self: Memory) Format {
        return switch (self) {
            inline else => |_, format| format,
        };
    }

    pub fn slice(self: Memory, start: usize, end: usize) Memory {
        var s: Memory = undefined;
        switch (self) {
            inline else => |memory, format| {
                @field(s, @tagName(format)) = memory[start..end];
            },
        }
        return s;
    }

    pub fn bytes(self: Memory) []u8 {
        return switch (self) {
            inline else => |memory| @alignCast(std.mem.sliceAsBytes(memory)),
        };
    }
};

memory: Memory,
width: u32,
height: u32,

pub fn getFormat(self: Texture) Format {
    return self.memory.getFormat();
}

pub fn pitch(self: *const Texture) usize {
    return self.width * self.getFormat().bytesPerPixel();
}

pub fn size(self: *const Texture) usize {
    return self.height * self.pitch();
}

pub fn Raw(comptime format: Format) type {
    return struct {
        memory: []format.BackingType(),
        format: Format,
        width: u32,
        height: u32,
    };
}
pub fn raw(self: Texture, comptime format: Format) Raw(format) {
    switch (self.memory) {
        inline else => |memory, fmt| {
            comptime std.debug.assert(fmt == format);
            return .{
                .memory = memory,
                .format = format,
                .width = self.width,
                .height = self.height,
            };
        },
    }
}
