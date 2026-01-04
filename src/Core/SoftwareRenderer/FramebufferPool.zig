const std = @import("std");
const utils = @import("utils");
const Texture = @import("Texture.zig");
const Mailbox = utils.Mailbox;
const Graphics = @import("../Graphics/Graphics.zig");

const FramebufferPool = @This();
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;
const Format = Graphics.Format;

const log = std.log.scoped(.FramebufferPool);
const assert = std.debug.assert;

allocator: Allocator,
backing_memory: Texture.Memory,
width: u32,
height: u32,

state: Mailbox = .{},
new_size: ?Size = null,
resize_state: Atomic(ResizeState) = .init(.idle),

const page_alignment = std.mem.Alignment.fromByteUnits(std.heap.pageSize());

pub const buffer_count = 3;

pub const ResizeState = enum(u8) {
    idle,
    requested,
    applied,
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

pub fn init(allocator: Allocator, width: u32, height: u32, format: Format) !FramebufferPool {
    const allocation_size = width * height * format.bytesPerPixel() * buffer_count;

    const allocation: []align(page_alignment.toByteUnits()) u8 = try allocator.alignedAlloc(
        u8,
        page_alignment,
        allocation_size,
    );
    @memset(allocation, 0);

    const backing_memory: Texture.Memory = switch (format) {
        .bgra8_u => .{
            .bgra8_u = @ptrCast(@alignCast(allocation)),
        },
    };

    return .{
        .allocator = allocator,
        .backing_memory = backing_memory,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: *const FramebufferPool, allocator: std.mem.Allocator) void {
    switch (self.backing_memory) {
        inline else => |memory| allocator.free(memory),
    }
}

pub fn requestResize(self: *FramebufferPool, new_width: u32, new_height: u32) void {
    const new_size: Size = .{ .width = new_width, .height = new_height };
    self.resize_state.store(.requested, .release);

    self.state.discardReady();

    self.new_size = new_size;
}

pub fn acquire(self: *FramebufferPool) ?Texture {
    if (self.resizeState() == .requested) {
        if (self.state.isIdle()) {
            self.applyResize();
        } else {
            return null;
        }
    }
    const index = self.state.acquire();
    return self.getFramebuffer(index);
}

pub fn publish(self: *FramebufferPool, framebuffer: Texture) void {
    if (self.resizeState() == .requested) {
        self.state.is_writing.store(false, .release);
        return;
    }
    self.state.publish(self.getIndex(framebuffer));
}

pub fn consume(self: *FramebufferPool) ?Texture {
    if (self.resizeState() == .requested) {
        self.state.discardReady();
        return null;
    }
    return if (self.state.consume()) |index| self.getFramebuffer(index) else null;
}

pub fn release(self: *FramebufferPool, framebuffer: Texture) void {
    const fb_index = self.getIndex(framebuffer);
    assert(fb_index == self.state.read_idx.load(.monotonic));
    self.state.release();
}

pub fn resizeState(self: *const FramebufferPool) ResizeState {
    return self.resize_state.load(.acquire);
}

pub fn consumeResize(self: *FramebufferPool) void {
    assert(self.resize_state.load(.acquire) == .applied);
    self.resize_state.store(.idle, .release);
}

fn applyResize(self: *FramebufferPool) void {
    log.debug("applying framebuffer resize, new_width: {}, new_height: {}", .{ self.new_size.?.width, self.new_size.?.height });
    if (!self.state.isIdle()) {
        log.err("cannot apply resize: not all buffers are avalible", .{});
        return;
    }
    const allocator = self.allocator;
    const format = self.backing_memory.getFormat();
    const new_size = self.new_size orelse return;
    self.deinit(allocator);
    self.* = FramebufferPool.init(allocator, new_size.width, new_size.height, format) catch @panic("falied to apply resize");

    self.resize_state.store(.applied, .release);
    log.info("resized framebuffers to {}x{}", .{ self.width, self.height });
}

fn getFramebuffer(self: *const FramebufferPool, index: usize) Texture {
    const start = index * self.pixelsPerBuffer();
    const end = start + self.width * self.height;

    const memory = self.backing_memory.slice(start, end);
    return .{
        .memory = memory,
        .width = self.width,
        .height = self.height,
    };
}

fn getIndex(self: *const FramebufferPool, framebuffer: Texture) u2 {
    assert(@intFromPtr(framebuffer.memory.bytes().ptr) >= @intFromPtr(self.backing_memory.bytes().ptr));

    const offset_bytes = @intFromPtr(framebuffer.memory.bytes().ptr) - @intFromPtr(self.backing_memory.bytes().ptr);
    const offset_pixels = offset_bytes / self.backing_memory.getFormat().bytesPerPixel();
    assert(offset_pixels % self.pixelsPerBuffer() == 0);

    const index: usize = offset_pixels / self.pixelsPerBuffer();
    if (index != 0) {}
    assert(index < buffer_count);
    return @intCast(index);
}

// fn byteOffset(self: *const FramebufferPool, index: usize) usize {
//     const byte_offset = self.maxPixelsPerBuffer() * self.format.bytes_per_pixel * index;
//     // sanity check: computed byte address must equal slice ptr
//     const base_addr = @intFromPtr(self.backing_memory.ptr);
//     const expect_ptr = base_addr + byte_offset;
//     const actual_ptr = @intFromPtr(self.framebuffers[index].memory.ptr);
//
//     if (expect_ptr != actual_ptr) {
//         log.err("Framebuffer offset mismatch: expect {}, actual {}\n", .{ expect_ptr, actual_ptr });
//         unreachable;
//     }
//     return byte_offset;
// }

fn pixelsPerBuffer(self: *const FramebufferPool) usize {
    return self.width * self.height;
}
