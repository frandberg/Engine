const std = @import("std");
const objc = @import("objc");

const glue = @import("glue");

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const FramebufferPool = @This();

backing_memory: []u32,
buffer_count: u32,
width: u32,
height: u32,
state: Atomic(State) = Atomic(State).init(.{}),
pending_resize: Atomic(bool) = Atomic(bool).init(false),

pub const AtomicUSize = std.atomic.Value(usize);

const Atomic = std.atomic.Value;

pub const bytes_per_pixel: u32 = @sizeOf(u32);

const max_buffer_count: usize = 32;

pub const State = packed struct(u64) {
    buffers_in_use: u32 = 0,
    ready_index: u32 = 0,
};

pub const Info = struct {
    buffer_count: u32,
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

pub fn pixelsPerBuffer(self: *const FramebufferPool) usize {
    std.debug.assert(self.buffer_count < max_buffer_count);
    return std.math.divExact(usize, self.backing_memory.len, self.buffer_count) catch @panic("invalid division");
}

fn bufferByteOffset(self: *const FramebufferPool, index: usize) usize {
    const byte_offset = self.pixelsPerBuffer() * bytes_per_pixel * index;

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
    const start = index * self.pixelsPerBuffer();
    const end = start + self.width * self.height;
    const memory = self.backing_memory[start..end];

    return .{
        .memory = memory,
        .width = self.width,
        .height = self.height,
    };
}

pub fn acquireNextFreeBuffer(self: *FramebufferPool) ?Framebuffer {
    if (self.pending_resize.load(.acquire)) {
        return null;
    }
    const state = self.state.load(.acquire);
    for (0..self.buffer_count) |i| {
        const index_bit = @as(u32, 1) << @as(u5, @intCast(i));
        if (state.buffers_in_use & index_bit != 0) continue;
        if (index_bit & state.buffers_in_use == 0) {
            CASState(true, null, &self.state, i);
            return self.getBuffer(i);
        }
    }
    return null;
}

pub fn acquireReadyBuffer(self: *FramebufferPool) ?Framebuffer {
    if (self.pending_resize.load(.acquire)) {
        return null;
    }
    std.debug.assert(self.buffer_count < max_buffer_count);

    const ready_index_bit = self.state.load(.acquire).ready_index;
    if (ready_index_bit != 0) {
        const ready_index = std.math.log2(ready_index_bit);
        std.debug.assert(ready_index < self.buffer_count);

        CASState(true, false, &self.state, ready_index);
        return self.getBuffer(ready_index);
    }
    return null;
}

pub fn releaseBufferAndMakeReady(self: *FramebufferPool, framebuffer: *const Framebuffer) void {
    const index = getBufferIndex(self, framebuffer);
    CASState(false, true, &self.state, index);
}

pub fn releaseBuffer(self: *FramebufferPool, framebuffer: *const Framebuffer) void {
    const index = getBufferIndex(self, framebuffer);
    CASState(false, null, &self.state, index);
}

fn getBufferIndex(self: *const FramebufferPool, framebuffer: *const Framebuffer) usize {
    std.debug.assert(@intFromPtr(framebuffer.memory.ptr) >= @intFromPtr(self.backing_memory.ptr));
    const offset = @intFromPtr(framebuffer.memory.ptr) - @intFromPtr(self.backing_memory.ptr);
    std.debug.assert(offset % self.pixelsPerBuffer() == 0);
    const index: usize = offset / self.pixelsPerBuffer();
    std.debug.assert(index < self.buffer_count);
    return index;
}

fn CASState(comptime in_use: ?bool, comptime ready: ?bool, state: *Atomic(State), index: usize) void {
    std.debug.assert(index < 32);

    var old_state = state.load(.seq_cst);
    var new_state = newState(in_use, ready, old_state, index);

    while (state.cmpxchgStrong(
        old_state,
        new_state,
        .acq_rel,
        .acquire,
    )) |updated_state| {
        old_state = updated_state;
        new_state = newState(in_use, ready, old_state, index);
    } else return;
}

fn newState(comptime in_use: ?bool, comptime ready: ?bool, state: State, index: usize) State {
    var new_state = state;

    const index_bit = @as(u32, 1) << @as(u5, @intCast(index));

    if (in_use) |value| {
        if (value) {
            if (state.buffers_in_use & index_bit != 0) {
                std.log.err("Attempting to acquire a buffer that is already in use: {}", .{index});
                unreachable;
            }
            new_state.buffers_in_use |= index_bit;
        } else {
            if (state.buffers_in_use & index_bit == 0) {
                std.log.err("Attempting to release a buffer that is not in use: {}", .{index});
                unreachable;
            }
            new_state.buffers_in_use &= ~index_bit;
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
