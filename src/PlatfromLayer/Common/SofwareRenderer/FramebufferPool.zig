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
buffer_pool: BufferPool(3),

pub const bytes_per_pixel: u32 = @sizeOf(u32);
pub const buffer_count = 3;

const max_buffer_count: usize = 8;

pub const State = packed struct(u8) {
    in_use_index_bits: u3 = 0,
    ready_index_bit: u3 = 0,
    pending_resize: bool = false,
    _reserved: u1 = 0,
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

    const backing_memory = try allocaor.alignedAlloc(u32, std.mem.Alignment.fromByteUnits(std.heap.pageSize()), allocation_size);
    @memset(backing_memory, 0);

    return .{
        .backing_memory = backing_memory,
        .width = info.width,
        .height = info.height,
        .buffer_pool = .{},
    };
}

pub fn deinit(self: *const FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn resize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    assert(new_width > 0 and new_height > 0);
    assert(new_width * new_height <= self.maxPixelsPerBuffer());

    var state = self.state.load(.seq_cst);
    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_index_bits = state.in_use_index_bits,
            .ready_index_bit = state.ready_index_bit,
            .pending_resize = true,
        },
        .acq_rel,
        .monotonic,
    )) |new_state| {
        state = new_state;
    }

    while (self.state.load(.seq_cst).in_use_index_bits != 0) {}
    if (new_width * new_height < self.width * self.height) {
        inline for (0..buffer_count) |i| {
            const buffer = self.getBuffer(i);
            @memset(buffer.memory[new_width * new_height .. self.width * self.height], 0);
        }
    }
    self.width = new_width;
    self.height = new_height;
    self.state.store(.{
        .in_use_index_bits = 0,
        .ready_index_bit = 0,
        .pending_resize = false,
    }, .seq_cst);
    log.debug("FramebufferPool resized to {}x{}\n", .{ new_width, new_height });
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

pub fn acquireNextFreeBuffer(self: *FramebufferPool) ?Framebuffer {
    const ret = if (self.buffer_pool.acquireForWrite()) |index| self.getBuffer(index) else null;
    return ret;
}
// pub fn acquireNextFreeBuffer(self: *FramebufferPool) ?Framebuffer {
//     var state = self.state.load(.monotonic);
//
//     const all_indices_ocupied: u3 = 0b111;
//
//     while (true) {
//         assertStateValid(state);
//         if (state.pending_resize or (state.in_use_index_bits == all_indices_ocupied)) {
//             return null;
//         }
//         const index_bit: u3 = nextFreeIndexBit(state) orelse return null;
//         assert(index_bit & state.ready_index_bit == 0);
//
//         if (self.state.cmpxchgStrong(
//             state,
//             .{
//                 .in_use_index_bits = state.in_use_index_bits | index_bit,
//                 .ready_index_bit = state.ready_index_bit,
//                 .pending_resize = false,
//             },
//             .acquire,
//             .monotonic,
//         )) |new_state| {
//             state = new_state;
//         } else {
//             return self.getBuffer(@ctz(index_bit));
//         }
//     }
// }

pub fn releaseBufferAndMakeReady(self: *FramebufferPool, framebuffer: Framebuffer) void {
    self.buffer_pool.finishWrite(self.getBufferIndex(framebuffer));
}
// pub fn releaseBufferAndMakeReady(self: *FramebufferPool, framebuffer: Framebuffer) void {
//     var state = self.state.load(.monotonic);
//
//     const index = getBufferIndex(self, framebuffer);
//     const index_bit: u3 = @as(u3, 1) << index;
//
//     while (true) {
//         assertStateValid(state);
//         assert(state.in_use_index_bits & index_bit != 0);
//         assert(state.ready_index_bit & index_bit == 0);
//         if (self.state.cmpxchgStrong(
//             state,
//             .{
//                 .in_use_index_bits = state.in_use_index_bits & ~index_bit,
//                 .ready_index_bit = index_bit,
//                 .pending_resize = state.pending_resize,
//             },
//             .release,
//             .monotonic,
//         )) |new_state| {
//             state = new_state;
//         } else {
//             return;
//         }
//     }
// }

pub fn acquireReadyBuffer(self: *FramebufferPool) ?Framebuffer {
    const ret = if (self.buffer_pool.acquireForRead()) |index| self.getBuffer(index) else null;
    return ret;
}
// pub fn acquireReadyBuffer(self: *FramebufferPool) ?Framebuffer {
//     var state = self.state.load(.monotonic);
//
//     while (true) {
//         assertStateValid(state);
//         if (state.ready_index_bit == 0 or state.pending_resize) {
//             return null;
//         }
//         assert(state.ready_index_bit & state.in_use_index_bits == 0);
//
//         const acquire_index = state.ready_index_bit;
//         if (self.state.cmpxchgStrong(
//             state,
//             .{
//                 .in_use_index_bits = state.in_use_index_bits | state.ready_index_bit,
//                 .ready_index_bit = 0,
//                 .pending_resize = false,
//             },
//             .acquire,
//             .monotonic,
//         )) |new_state| {
//             state = new_state;
//         } else {
//             return self.getBuffer(@ctz(acquire_index));
//         }
//     }
// }

pub fn releaseBuffer(self: *FramebufferPool, framebuffer: Framebuffer) void {
    self.buffer_pool.finishRead(self.getBufferIndex(framebuffer));
}
// pub fn releaseBuffer(self: *FramebufferPool, framebuffer: Framebuffer) void {
//     var state = self.state.load(.monotonic);
//
//     const index = getBufferIndex(self, framebuffer);
//     const index_bit: u3 = @as(u3, 1) << index;
//
//     while (true) {
//         assertStateValid(state);
//         assert(state.in_use_index_bits & index_bit != 0);
//         assert(state.ready_index_bit & index_bit == 0);
//         if (self.state.cmpxchgStrong(
//             state,
//             .{
//                 .in_use_index_bits = state.in_use_index_bits & ~index_bit,
//                 .ready_index_bit = state.ready_index_bit,
//                 .pending_resize = state.pending_resize,
//             },
//             .release,
//             .monotonic,
//         )) |new_state| {
//             state = new_state;
//         } else {
//             return;
//         }
//     }
// }

fn assertStateValid(state: State) void {
    assert(@popCount(state.ready_index_bit) <= 1);
    assert(state._reserved == 0);
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
