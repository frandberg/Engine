const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const FramebufferPool = @This();

pub const AtomicUSize = std.atomic.Value(usize);

pub const buffer_count: usize = 3;
pub const bytes_per_pixel: u32 = @sizeOf(u32);
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
        return self.width * bytes_per_pixel;
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
framebuffers: [buffer_count]Framebuffer,
ready_index: AtomicUSize = AtomicUSize.init(invalid_framebuffer_index),
present_index: AtomicUSize = AtomicUSize.init(invalid_framebuffer_index),

state_of_buffers: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

pub fn init(allocaor: std.mem.Allocator, info: Info) !FramebufferPool {
    const allocation_size = info.max_width * info.max_height * buffer_count;

    const backing_memory = try allocaor.alignedAlloc(u32, std.heap.pageSize(), allocation_size);
    @memset(backing_memory, 0);

    var buffers: [buffer_count]Framebuffer = undefined;
    for (&buffers, 0..) |*buffer, i| {
        const start_index = i * (std.math.divExact(usize, backing_memory.len, buffer_count) catch @panic("invalid division"));
        const end_index = start_index + info.width * info.height;
        buffer.* = .{
            .memory = backing_memory[start_index..end_index],
            .width = info.width,
            .height = info.height,
        };
        std.debug.assert(buffer.memory.len == info.width * info.height);
    }

    return FramebufferPool{
        .backing_memory = backing_memory,
        .framebuffers = buffers,
    };
}

pub fn deinit(self: *FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn pixelsPerBuffer(self: *const FramebufferPool) usize {
    return std.math.divExact(usize, self.backing_memory.len, buffer_count) catch @panic("invalid division");
}

pub fn bufferOffset(self: *const FramebufferPool, index: usize) usize {
    const byte_offset = self.pixelsPerBuffer() * bytes_per_pixel * index;

    // sanity check: computed byte address must equal slice ptr
    const base_addr = @intFromPtr(self.backing_memory.ptr);
    const expect_ptr = base_addr + byte_offset;
    const actual_ptr = @intFromPtr(self.framebuffers[index].memory.ptr);

    if (expect_ptr != actual_ptr) {
        std.debug.print("Buffer offset mismatch: expect {}, actual {}\n", .{ expect_ptr, actual_ptr });
        unreachable;
    }
    return byte_offset; // Metal's sourceOffset expects BYTES
}
