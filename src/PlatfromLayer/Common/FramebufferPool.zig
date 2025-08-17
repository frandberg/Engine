const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const FramebufferPool = @This();
const Atomic = std.atomic.Value;

backing_memory: []u32,
buffer_count: u3,
width: u32,
height: u32,
state: Atomic(State) = Atomic(State).init(.{}),

pub const bytes_per_pixel: u32 = @sizeOf(u32);

const max_buffer_count: usize = 8;

pub const State = packed struct(u64) {
    in_use_indices: u8 = 0,
    ready_index: u8 = 0,
    pending_resize: bool = false,
    _reserved: u47 = 0,
};

pub const Info = struct {
    buffer_count: u3,
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

pub fn init(allocaor: std.mem.Allocator, info: Info) !FramebufferPool {
    const allocation_size = info.max_width * info.max_height * info.buffer_count;

    const backing_memory = try allocaor.alignedAlloc(u32, std.heap.pageSize(), allocation_size);
    @memset(backing_memory, 0);

    return .{
        .backing_memory = backing_memory,
        .buffer_count = info.buffer_count,
        .width = info.width,
        .height = info.height,
    };
}

pub fn deinit(self: *FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn resize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    std.debug.assert(new_width > 0 and new_height > 0);
    std.debug.assert(new_width * new_height <= self.maxPixelsPerBuffer());

    var state = self.state.load(.seq_cst);
    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_indices = state.in_use_indices,
            .ready_index = state.ready_index,
            .pending_resize = true,
        },
        .seq_cst,
        .seq_cst,
    )) |new_state| {
        state = new_state;
    }

    while (self.state.load(.seq_cst).in_use_indices != 0) {
        std.time.sleep(1000);
    }
    if (new_width * new_height < self.width * self.height) {
        for (0..self.buffer_count) |i| {
            const buffer = self.getBuffer(i);
            @memset(buffer.memory[new_width * new_height .. self.width * self.height], 0);
        }
    }
    self.width = new_width;
    self.height = new_height;
    self.state.store(.{
        .in_use_indices = 0,
        .ready_index = 0,
        .pending_resize = false,
    }, .seq_cst);
    std.log.debug("FramebufferPool resized to {}x{}\n", .{ new_width, new_height });
}

pub fn maxPixelsPerBuffer(self: *const FramebufferPool) usize {
    return std.math.divExact(usize, self.backing_memory.len, self.buffer_count) catch @panic("invalid division");
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
    std.debug.assert(index < max_buffer_count);
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
    var state = self.state.load(.seq_cst);
    if (state._reserved != 0) {
        std.log.err("Reserved bits are not zero, state is currupted: {}", .{state._reserved});
        unreachable;
    }

    const all_indices_ocupied: u8 = @as(u8, 1) << @as(u3, self.buffer_count) - 1;
    if (state.pending_resize or (state.in_use_indices == all_indices_ocupied)) {
        return null;
    }
    var index_bit = nextFreeIndexBit(state, self.buffer_count) orelse return null;

    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_indices = state.in_use_indices | index_bit,
            .ready_index = state.ready_index,
            .pending_resize = false,
        },
        .seq_cst,
        .seq_cst,
    )) |new_state| {
        if (state.pending_resize or (state.in_use_indices == all_indices_ocupied)) {
            return null;
        }
        state = new_state;
        index_bit = nextFreeIndexBit(state, self.buffer_count) orelse return null;
    } else {
        return self.getBuffer(@ctz(index_bit));
    }
    return null;
}

fn nextFreeIndexBit(state: State, buffer_count: u3) ?u8 {
    std.debug.assert(state.ready_index == 0 or std.math.isPowerOfTwo(state.ready_index));
    std.debug.assert(buffer_count != 0);
    const mask: u8 = @as(u8, 1) << buffer_count - 1;

    const candidates: u8 = (~state.in_use_indices) & (~state.ready_index) & mask;

    if (candidates == 0) return null;

    return candidates & ~candidates + 1; //lowest candidate
}

pub fn acquireReadyBuffer(self: *FramebufferPool) ?Framebuffer {
    var state = self.state.load(.seq_cst);
    if (state._reserved != 0) {
        std.log.err("Reserved bits are not zero, state is currupted: {}", .{state._reserved});
        unreachable;
    }

    if (self.state.load(.seq_cst).pending_resize) {
        return null;
    }
    std.debug.assert(self.buffer_count < max_buffer_count);

    if (state.ready_index == 0) {
        return null;
    }

    if (state.ready_index & state.in_use_indices != 0) {
        std.log.err("Ready index {} is in use", .{state.ready_index});
        unreachable;
    }
    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_indices = state.in_use_indices | state.ready_index,
            .ready_index = 0,
            .pending_resize = false,
        },
        .seq_cst,
        .seq_cst,
    )) |new_state| {
        if (new_state.pending_resize) {
            return null;
        }
        if (new_state.ready_index == 0) {
            return null;
        }

        if (state.ready_index & state.in_use_indices != 0) {
            std.log.err("Ready index {} is in use", .{state.ready_index});
            unreachable;
        }
        state = new_state;
    }
    std.debug.assert(std.math.isPowerOfTwo(state.ready_index));
    const ready_index = std.math.log2(state.ready_index);
    return self.getBuffer(ready_index);
}

pub fn releaseBufferAndMakeReady(self: *FramebufferPool, framebuffer: *const Framebuffer) void {
    const index = getBufferIndex(self, framebuffer);

    const index_bit: u8 = @as(u8, 1) << @as(u3, @intCast(index));
    var state = self.state.load(.seq_cst);

    if (state._reserved != 0) {
        std.log.err("Reserved bits are not zero, state is currupted: {}", .{state._reserved});
        unreachable;
    }
    if (state.in_use_indices & index_bit == 0) {
        std.log.err("trying to release buffer not in use\n", .{});
        unreachable;
    }

    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_indices = state.in_use_indices & ~index_bit,
            .ready_index = index_bit,
            .pending_resize = state.pending_resize,
        },
        .seq_cst,
        .seq_cst,
    )) |new_state| {
        state = new_state;
    }
}

pub fn releaseBuffer(self: *FramebufferPool, framebuffer: *const Framebuffer) void {
    const index = getBufferIndex(self, framebuffer);
    const index_bit: u8 = @as(u8, 1) << @as(u3, @intCast(index));
    var state = self.state.load(.seq_cst);
    if (state._reserved != 0) {
        std.log.err("Reserved bits are not zero, state is currupted: {}", .{state._reserved});
        unreachable;
    }
    if (state.in_use_indices & index_bit == 0) {
        std.log.err("trying to release buffer not in use\n", .{});
        unreachable;
    }
    if (state.ready_index & index_bit != 0) {
        std.log.err("releasing ready buffer not allowed\n", .{});
        unreachable;
    }

    while (self.state.cmpxchgStrong(
        state,
        .{
            .in_use_indices = state.in_use_indices & ~index_bit,
            .ready_index = state.ready_index,
            .pending_resize = state.pending_resize,
        },
        .seq_cst,
        .seq_cst,
    )) |new_state| {
        state = new_state;
    }
}

fn getBufferIndex(self: *const FramebufferPool, framebuffer: *const Framebuffer) usize {
    std.debug.assert(@intFromPtr(framebuffer.memory.ptr) >= @intFromPtr(self.backing_memory.ptr));
    const offset_bytes = @intFromPtr(framebuffer.memory.ptr) - @intFromPtr(self.backing_memory.ptr);
    const offset_pixels = offset_bytes / bytes_per_pixel;
    std.debug.assert(offset_pixels % self.maxPixelsPerBuffer() == 0);
    const index: usize = offset_pixels / self.maxPixelsPerBuffer();
    if (index >= self.buffer_count) {
        std.debug.print("Buffer index: {}, buffer_count: {}\n", .{ index, self.buffer_count });
    }
    std.debug.assert(index < self.buffer_count);
    return index;
}

fn CASState(comptime in_use: ?bool, comptime ready: ?bool, state: *Atomic(State), index: usize) void {
    std.debug.assert(index < max_buffer_count);

    var old_state = state.load(.seq_cst);
    var new_state = newState(in_use, ready, old_state, index);

    while (state.cmpxchgStrong(
        old_state,
        new_state,
        .seq_cst,
        .seq_cst,
    )) |updated_state| {
        old_state = updated_state;
        new_state = newState(in_use, ready, old_state, index);
    } else return;
}

fn newState(comptime in_use: ?bool, comptime ready: ?bool, state: State, index: usize) State {
    var new_state = state;
    comptime if (in_use) |in_use_val| {
        if (ready) |ready_val| {
            std.debug.assert(!(in_use_val == true and ready_val == true));
            std.debug.assert(!(in_use_val == false and ready_val == false));
        }
    };

    const index_bit = @as(u8, 1) << @as(u3, @intCast(index));

    if (in_use) |value| {
        if (value) {
            if (state.pending_resize) {
                std.log.err("Attempting to.seq_cst a buffer while a resize is pending: {}", .{index});
                unreachable;
            }
            if (state.in_use_indices & index_bit != 0) {
                std.log.err("Attempting to.seq_cst a buffer that is already in use: {}", .{index});
                unreachable;
            }
            new_state.in_use_indices |= index_bit;
        } else {
            if (state.in_use_indices & index_bit == 0) {
                std.log.err("Attempting to release a buffer that is not in use: {}", .{index});
                unreachable;
            }
            new_state.in_use_indices &= ~index_bit;
        }
    }

    if (ready) |value| {
        if (value) {
            new_state.ready_index = index_bit;
        } else {
            new_state.ready_index &= ~index_bit;
        }
    }

    return new_state;
}
