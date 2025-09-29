const std = @import("std");
const objc = @import("objc");
const BufferPool = @import("../BufferPool.zig").BufferPool;

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const FramebufferPool = @This();
const Atomic = std.atomic.Value;

const log = std.log.scoped(.FramebufferPool);
const assert = std.debug.assert;

backing_memory: []u32,
width: u32,
height: u32,
// state: Atomic(State) align(8) = Atomic(State).init(.{}),
//
mem_index: usize = 0,
buffer_pool: BufferPool(3) = .{},
new_size: std.atomic.Value(Size) = std.atomic.Value(Size).init(.{
    .width = std.math.maxInt(u32),
    .height = std.math.maxInt(u32),
}),

pub const bytes_per_pixel: u32 = @sizeOf(u32);
pub const buffer_count = 3;

const max_buffer_count: usize = 8;

pub const State = packed struct(u8) {
    in_use_index_bits: u3 = 0,
    ready_index_bit: u3 = 0,
    pending_resize: bool = false,
    _reserved: u1 = 0,
};

const Size = packed struct(u64) {
    width: u32,
    height: u32,
};

const null_size: Size = .{
    .width = std.math.maxInt(u32),
    .height = std.math.maxInt(u32),
};

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

    pub const bytes_per_pixel: u32 = FramebufferPool.bytes_per_pixel;

    pub fn pitch(self: *const Framebuffer) usize {
        return self.width * Framebuffer.bytes_per_pixel;
    }

    pub fn size(self: *const Framebuffer) usize {
        return self.pitch() * self.height;
    }
    pub fn clear(self: *const Framebuffer, color: u32) void {
        @memset(self.memory[0 .. self.width * self.height], color);
    }
};

pub fn init(allocaor: std.mem.Allocator, info: Info) !FramebufferPool {
    const allocation_size = info.max_width * info.max_height * buffer_count;

    const backing_memory = try allocaor.alignedAlloc(
        u32,
        std.mem.Alignment.fromByteUnits(std.heap.pageSize()),
        allocation_size,
    );
    @memset(backing_memory, 0);

    return .{
        .backing_memory = backing_memory,
        .width = info.width,
        .height = info.height,
    };
}

pub fn deinit(self: *const FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn resize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    const new_size: Size = .{ .width = new_width, .height = new_height };
    assert(new_size != null_size);
    self.new_size.store(new_size, .monotonic);
    log.debug("resized", .{});
}

pub fn maxPixelsPerBuffer(self: *const FramebufferPool) usize {
    return std.math.divExact(usize, self.backing_memory.len, buffer_count) catch @panic("invalid division");
}

fn bufferByteOffset(self: *const FramebufferPool, index: usize) usize {
    const byte_offset = self.maxPixelsPerBuffer() * bytes_per_pixel * index;

    // sanity check: computed byte address must equal slice ptr
    const base_addr = @intFromPtr(self.backing_memory.ptr);
    const expect_ptr = base_addr + byte_offset;
    const actual_ptr = @intFromPtr(self.framebuffers[index].memory.ptr);

    if (expect_ptr != actual_ptr) {
        std.debug.print("Buffer offset mismatch: expect {}, actual {}\n", .{ expect_ptr, actual_ptr });
        unreachable;
    }
    return byte_offset;
}

fn getBuffer(self: *const FramebufferPool, index: usize) Framebuffer {
    assert(index < max_buffer_count);
    const start = index * self.maxPixelsPerBuffer();
    const end = start + self.width * self.height;
    const memory = self.backing_memory[start..end];

    return .{
        .memory = memory,
        .width = self.width,
        .height = self.height,
    };
}

pub fn acquireFree(self: *FramebufferPool) ?Framebuffer {
    if (self.needsResize()) {
        if (self.buffer_pool.state.load(.monotonic).in_use_index_bits == 0) {
            self.applyResize();
        } else {
            return null;
        }
    }
    return if (self.buffer_pool.acquireFree()) |index| self.getBuffer(index) else null;
}

pub fn releaseReady(self: *FramebufferPool, framebuffer: Framebuffer) void {
    const discard = self.needsResize();
    self.buffer_pool.releaseReady(self.getBufferIndex(framebuffer), discard);
}

pub fn acquireReady(self: *FramebufferPool) ?Framebuffer {
    if (self.needsResize()) {
        return null;
    }
    return if (self.buffer_pool.acquireReady()) |index| self.getBuffer(index) else null;
}

pub fn release(self: *FramebufferPool, framebuffer: Framebuffer) void {
    self.buffer_pool.release(self.getBufferIndex(framebuffer));
}

pub fn needsResize(self: *FramebufferPool) bool {
    if (self.new_size.load(.monotonic) != null_size) {
        return true;
    }
    return false;
}

fn applyResize(self: *FramebufferPool) void {
    const new_size = self.new_size.load(.monotonic);
    assert(new_size != null_size);
    self.width = new_size.width;
    self.height = new_size.height;
    self.new_size.store(null_size, .monotonic);
}

fn nextFreeIndexBit(state: State) ?u3 {
    assert(state.ready_index_bit == 0 or std.math.isPowerOfTwo(state.ready_index_bit));
    assert(buffer_count != 0);
    const mask: u3 = @as(u3, 1) << buffer_count - 1;

    const candidates: u3 = (~state.in_use_index_bits) & (~state.ready_index_bit) & mask;

    if (candidates == 0) return null;

    return candidates & ~candidates + 1; //lowest candidate
}

fn getBufferIndex(self: *const FramebufferPool, framebuffer: Framebuffer) u2 {
    assert(@intFromPtr(framebuffer.memory.ptr) >= @intFromPtr(self.backing_memory.ptr));
    const offset_bytes = @intFromPtr(framebuffer.memory.ptr) - @intFromPtr(self.backing_memory.ptr);
    const offset_pixels = offset_bytes / bytes_per_pixel;
    assert(offset_pixels % self.maxPixelsPerBuffer() == 0);
    const index: usize = offset_pixels / self.maxPixelsPerBuffer();
    assert(index < buffer_count);
    return @intCast(index);
}
