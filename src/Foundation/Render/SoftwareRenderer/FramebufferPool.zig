const std = @import("std");
const utils = @import("utils");
const Mailbox = utils.Mailbox;

const FramebufferPool = @This();
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.FramebufferPool);
const assert = std.debug.assert;

allocator: Allocator,
backing_memory: []u32,
width: u32,
height: u32,

mem_index: usize = 0,
state: Mailbox = .{},
new_size: ?Size = null,
resize_state: Atomic(ResizeState) = .init(.idle),

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

pub fn init(allocator: Allocator, width: u32, height: u32) !FramebufferPool {
    const allocation_size = width * height * buffer_count;

    const backing_memory = try allocator.alignedAlloc(
        u32,
        page_alignment,
        allocation_size,
    );
    @memset(backing_memory, 0);

    return .{
        .allocator = allocator,
        .backing_memory = backing_memory,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: *const FramebufferPool, allocator: std.mem.Allocator) void {
    allocator.free(self.backing_memory);
}

pub fn requestResize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    const new_size: Size = .{ .width = new_width, .height = new_height };

    self.resize_state.store(.in_progress, .release);
    self.state.discardReady();

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
        log.err("Buffer offset mismatch: expect {}, actual {}\n", .{ expect_ptr, actual_ptr });
        unreachable;
    }
    return byte_offset;
}

pub fn getBuffer(self: *const FramebufferPool, index: usize) Framebuffer {
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

pub fn acquire(self: *FramebufferPool) ?Framebuffer {
    if (self.isResizeing()) {
        if (self.state.isIdle()) {
            self.applyResize();
        } else {
            return null;
        }
    }
    const index = self.state.acquire();
    return self.getBuffer(index);
}

pub fn publish(self: *FramebufferPool, framebuffer: Framebuffer) void {
    if (self.isResizeing()) {
        self.state.is_writing.store(false, .release);
        return;
    }
    self.state.publish(self.getBufferIndex(framebuffer));
}

pub fn consume(self: *FramebufferPool) ?Framebuffer {
    if (self.isResizeing()) {
        self.state.discardReady();
        return null;
    }
    return if (self.state.consume()) |index| self.getBuffer(index) else null;
}

pub fn release(self: *FramebufferPool, framebuffer: Framebuffer) void {
    const fb_index = self.getBufferIndex(framebuffer);
    assert(fb_index == self.state.read_idx.load(.monotonic));
    self.state.release();
}
pub fn isResizeing(self: *const FramebufferPool) bool {
    return self.resize_state.load(.acquire) == .in_progress;
}

fn applyResize(self: *FramebufferPool) void {
    if (!self.state.isIdle()) {
        log.err("cannot apply resize: not all buffers are avalible", .{});
        return;
    }
    const new_size = self.new_size orelse return;
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

pub fn getBufferIndex(self: *const FramebufferPool, framebuffer: Framebuffer) u2 {
    assert(@intFromPtr(framebuffer.memory.ptr) >= @intFromPtr(self.backing_memory.ptr));
    const offset_bytes = @intFromPtr(framebuffer.memory.ptr) - @intFromPtr(self.backing_memory.ptr);
    const offset_pixels = offset_bytes / bytes_per_pixel;
    assert(offset_pixels % self.maxPixelsPerBuffer() == 0);
    const index: usize = offset_pixels / self.maxPixelsPerBuffer();
    if (index != 0) {}
    assert(index < buffer_count);
    return @intCast(index);
}
