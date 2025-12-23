const std = @import("std");
const assert = std.debug.assert;

const Atomic = std.atomic.Value;
const log = std.log.scoped(.BufferPoolState);

const Self = @This();

const no_index: usize = std.math.maxInt(usize);
const count = 3;

ready_idx: Atomic(usize) = .init(no_index),
read_idx: Atomic(usize) = .init(no_index),
is_writing: Atomic(bool) = .init(false),

pub fn acquire(self: *Self) usize {
    self.is_writing.store(true, .release);
    return self.findWritable();
}

pub fn publish(self: *Self, index: usize) void {
    assert(self.read_idx.load(.acquire) != index);
    self.ready_idx.store(index, .release);
    self.is_writing.store(false, .release);
}

pub fn consume(self: *Self) ?usize {
    const index = self.ready_idx.swap(no_index, .acq_rel);
    if (index == no_index) {
        return null;
    }
    self.read_idx.store(index, .release);
    return index;
}

pub fn release(self: *Self) void {
    self.read_idx.store(no_index, .release);
}

pub fn discardReady(self: *Self) void {
    self.read_idx.store(no_index, .release);
}

pub fn isIdle(self: Self) bool {
    const read_idx = self.read_idx.load(.acquire);
    const is_writing = self.is_writing.load(.acquire);
    return !(is_writing and read_idx == no_index);
}

fn findWritable(self: Self) usize {
    const ready = self.ready_idx.load(.acquire);
    const read = self.read_idx.load(.acquire);
    for (0..count) |i| {
        if (i != ready and i != read) {
            return i;
        }
    }
    unreachable;
}
