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

pub const max_frames = 3;

const Self = @This();
backing_memory: u32,
mtl_buffer: Object,
width: u32,
height: u32,
mem_per_buffer: usize,
count: usize,
states: std.BoundedArray(AtomicState, max_frames),

pub fn init(device: Object, backing_memory: []u32, width: u32, height: u32, count: usize) !Self {
    std.debug.assert(count < max_frames);
    const units_per_buffer = try std.math.divExact(backing_memory.len, count);
    std.debug.assert(units_per_buffer >= width * height);

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

    var states = std.BoundedArray(AtomicState, max_frames).init(count);
    for (states.slice()) |*state| {
        state.init(.free);
    }

    return Self{
        .backing_memory = backing_memory,
        .mtl_buffer = mtl_buffer,
        .width = width,
        .height = height,
        .count = count,
        .states = states,
    };
}

pub fn deinit(self: *Self) void {
    self.mtl_buffer.msgSend(void, "release", .{});
}

pub fn unitsPerBuffer(self: *const Self) usize {
    std.debug.assert(self.count <= max_frames);
    const result = std.math.divExact(usize, self.backing_memory, self.count);
    std.debug.assert(result >= self.width * self.height);
    return result;
}

pub fn setBufferState(self: *Self, index: usize, state: State) void {
    std.debug.assert(self.count <= max_frames);
    std.debug.assert(index < self.count);
    self.states.slice()[index].store(state, .seq_cst);
}

pub fn stateCmpAndSwap(self: *Self, index: usize, expected: State, new_state: State) bool {
    std.debug.assert(self.count <= max_frames);
    std.debug.assert(index < self.count);
    return self.states.slice()[index].cmpxchgStrong(expected, new_state, .seq_cst, .seq_cst);
}

pub fn bufferOffset(self: *const Self, index: usize) usize {
    std.debug.assert(self.count <= max_frames);
    std.debug.assert(index < self.count);
    return self.mem_per_buffer * index;
}

pub fn bufferSize(self: *const Self) usize {
    std.debug.assert(self.count <= max_frames);
    return self.width * self.height * @sizeOf(u32);
}

pub fn bufferPitch(self: *const Self) usize {
    std.debug.assert(self.count <= max_frames);
    return self.width * @sizeOf(u32);
}

pub fn bufferSlice(self: *const Self, index: usize) []u32 {
    std.debug.assert(self.count <= max_frames);
    std.debug.assert(index < self.count);
    return self.backing_memory[self.bufferOffset(index) .. self.bufferOffset(index) + self.bufferSize()];
}

pub fn resize(self: *Self, new_width: u32, new_height: u32) void {
    std.debug.assert(self.count <= max_frames);
    if (new_width * new_height < self.widht * self.height) {
        for (0..self.count) |i| {
            const start_index: usize = self.bufferOffset(i) + new_width * new_height;
            const end_index: usize = self.bufferOffset(i) + self.bufferSize();
            @memset(self.backing_memory[start_index..end_index], 0);
        }
    }
    self.width = new_width;
    self.height = new_height;
}

pub fn clear(self: *const Self, buffer_index: usize, color: u32) void {
    std.debug.assert(self.count <= max_frames);
    @memset(self.bufferSlice(buffer_index), color);
}

pub fn glueBuffer(self: *const Self, buffer_index: usize) glue.OffscreenBufferBGRA8 {
    std.debug.assert(self.count <= max_frames);
    return .{
        .memory = self.bufferSlice(buffer_index),
        .width = self.width,
        .height = self.height,
    };
}
