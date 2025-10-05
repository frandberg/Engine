const std = @import("std");
const objc = @import("objc");
const BufferPoolState = @import("../BufferPoolState.zig").BufferPoolState(3);

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);

const FramebufferPool = @This();
const Atomic = std.atomic.Value;

const log = std.log.scoped(.FramebufferPool);
const assert = std.debug.assert;

allocator: std.mem.Allocator,
backing_memory: []u32,
width: u32,
height: u32,
// state: Atomic(State) align(8) = Atomic(State).init(.{}),
//
mem_index: usize = 0,
state: BufferPoolState = .{},
new_size: ?Size = null,
resize_state: Atomic(ResizeState) = Atomic(ResizeState).init(.idle),

const page_alignment = std.mem.Alignment.fromByteUnits(std.heap.pageSize());

pub const bytes_per_pixel: u32 = @sizeOf(u32);
pub const buffer_count = 3;

const max_buffer_count: usize = 8;

pub const ResizeState = enum(u8) {
    idle,
    in_progress,
    applied,
    _,
};

const Size = packed struct(u64) {
    width: u32,
    height: u32,
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

pub fn init(allocator: std.mem.Allocator, info: Info) !FramebufferPool {
    const allocation_size = info.width * info.height * buffer_count;

    const backing_memory = try allocator.alignedAlloc(
        u32,
        page_alignment,
        allocation_size,
    );
    @memset(backing_memory, 0);

    return .{
        .allocator = allocator,
        .backing_memory = backing_memory,
        .width = info.width,
        .height = info.height,
    };
}

pub fn deinit(self: *const FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn requestResize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    const new_size: Size = .{ .width = new_width, .height = new_height };
    assert(new_size != null_size);

    self.resize_state.store(.in_progress, .monotonic);
    std.debug.print("resize requested\n", .{});

    self.new_size = new_size;
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

pub fn acquireAvalible(self: *FramebufferPool) ?Framebuffer {
    if (self.isResizeing()) {
        if (self.state.avalibleBufferCount() == BufferPoolState.buffer_count) {
            self.applyResize();
        } else {
            return null;
        }
    }
    return if (self.state.acquireAvalible()) |index| self.getBuffer(index) else null;
}

pub fn releaseReady(self: *FramebufferPool, framebuffer: Framebuffer) void {
    const discard = self.isResizeing();
    if (discard) {}
    self.state.releaseReady(self.getBufferIndex(framebuffer), discard);
}

pub fn acquireReady(self: *FramebufferPool) ?Framebuffer {
    // std.debug.print("acquireReady\n", .{});
    if (self.isResizeing()) {
        // std.debug.print("failed to acquire ready\n", .{});
        return null;
    }
    return if (self.state.acquireReady()) |index| self.getBuffer(index) else null;
}

pub fn release(self: *FramebufferPool, framebuffer: Framebuffer) void {
    self.state.release(self.getBufferIndex(framebuffer));
}
pub fn isResizeing(self: *FramebufferPool) bool {
    return self.resize_state.load(.monotonic) == .in_progress;
}

fn applyResize(self: *FramebufferPool) void {
    const new_size = self.new_size.?;
    const allcation_size = new_size.width * new_size.height * buffer_count;
    const new_mem = self.allocator.alignedAlloc(u32, page_alignment, allcation_size) catch return;
    self.allocator.free(self.backing_memory);
    self.backing_memory = new_mem;
    self.width = new_size.width;
    self.height = new_size.height;
    self.new_size = null;
    self.resize_state.store(.applied, .release);
    log.info("resized framebuffers to {}x{}", .{ self.width, self.height });
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
