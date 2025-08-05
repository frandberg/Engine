const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

pub const State = enum(u32) {
    free,
    ready,
    in_use,
};

pub const AtomicState = std.atomic.Value(State);
pub const AtomicISize = std.atomic.Value(isize);

pub const Framebuffer = struct {
    memory: []u32,
    width: u32,
    height: u32,
    state: AtomicState,

    pub fn pitch(self: *const Framebuffer) usize {
        return self.width * pixels_per_unit;
    }

    pub fn size(self: *const Framebuffer) usize {
        return self.pitch() * self.height;
    }
    pub fn glueBuffer(self: *const Framebuffer) glue.OffscreenBufferBGRA8 {
        return .{
            .memory = self.memory.ptr,
            .width = self.width,
            .height = self.height,
        };
    }
};

pub const Info = struct {
    width: u32,
    height: u32,
    max_width: u32,
    max_height: u32,
};

pub const buffer_count: usize = 2;
pub const pixels_per_unit: usize = @sizeOf(u32);

const Self = @This();
backing_memory: []u32,
mtl_buffer: Object,
framebuffers: [buffer_count]Framebuffer,
latest_ready_index: AtomicISize,

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
        const start_index = info.max_width * info.max_height * i;
        const end_index = start_index + info.width * info.height;
        buffer.* = .{
            .memory = backing_memory[start_index..end_index],
            .width = info.width,
            .height = info.height,
            .state = AtomicState.init(.free),
        };
    }

    return Self{
        .backing_memory = backing_memory,
        .mtl_buffer = mtl_buffer,
        .framebuffers = buffers,
        .latest_ready_index = AtomicISize.init(-1),
    };
}

pub fn deinit(self: *Self) void {
    self.mtl_buffer.msgSend(void, "release", .{});
}

pub fn unitsPerBuffer(self: *const Self) usize {
    return std.math.divExact(usize, self.backing_memory.len / buffer_count, pixels_per_unit) catch @panic("invalid division");
}

pub fn bufferOffset(self: *const Self, index: usize) usize {
    return self.unitsPerBuffer() * index;
}
