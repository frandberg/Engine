const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const Self = @This();

pub const AtomicUSize = std.atomic.Value(usize);

pub const buffer_count: usize = 2;
pub const pixels_per_unit: u32 = @sizeOf(u32);
pub const invalid_framebuffer_index: usize = std.math.maxInt(usize);

pub const Info = struct {
    width: u32,
    height: u32,
    max_width: u32,
    max_height: u32,
};

pub const Framebuffer = struct {
    memory: []u32,
    width: u32,
    height: u32,

    pub fn pitch(self: *const Framebuffer) usize {
        return self.width * pixels_per_unit;
    }

    pub fn size(self: *const Framebuffer) usize {
        return self.pitch() * self.height;
    }
    pub fn clear(self: *const Framebuffer, color: u32) void {
        @memset(self.memory, color);
    }
    pub fn glueBuffer(self: *const Framebuffer) glue.OffscreenBufferBGRA8 {
        return .{
            .memory = self.memory.ptr,
            .width = self.width,
            .height = self.height,
        };
    }
};

backing_memory: []u32,
mtl_buffer: Object,
framebuffers: [buffer_count]Framebuffer,
ready_index: AtomicUSize = AtomicUSize.init(invalid_framebuffer_index),

pub fn init(allocaor: std.mem.Allocator, device: Object, info: Info) !Self {
    const allocation_size = info.max_width * info.max_height * buffer_count;

    const backing_memory = try allocaor.alignedAlloc(u32, std.heap.pageSize(), allocation_size);
    const mtl_buffer = device.msgSend(
        Object,
        "newBufferWithBytesNoCopy:length:options:deallocator:",
        .{
            @as(*anyopaque, backing_memory.ptr),
            @as(usize, backing_memory.len * @sizeOf(u32)),
            @as(usize, 0), // MTLResourceStorageModeShared
            nil,
        },
    );

    var buffers: [buffer_count]Framebuffer = undefined;
    for (&buffers, 0..) |*buffer, i| {
        const start_index = i * (std.math.divExact(usize, backing_memory.len, buffer_count) catch @panic("invalid division"));
        const end_index = start_index + (info.width * info.height);
        buffer.* = .{
            .memory = backing_memory[start_index..end_index],
            .width = info.width,
            .height = info.height,
        };
        std.debug.assert(buffer.memory.len == info.width * info.height);
    }

    return Self{
        .backing_memory = backing_memory,
        .mtl_buffer = mtl_buffer,
        .framebuffers = buffers,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.mtl_buffer.msgSend(void, "release", .{});
    allocator.free(self.backing_memory);
}

pub fn unitsPerBuffer(self: *const Self) usize {
    return std.math.divExact(usize, self.backing_memory.len, buffer_count) catch @panic("invalid division");
}

pub fn bufferOffset(self: *const Self, index: usize) usize {
    return self.unitsPerBuffer() * index;
}
