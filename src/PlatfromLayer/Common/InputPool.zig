const std = @import("std");
const Input = @import("Engine").Input;

const BufferPoolState = @import("BufferPoolState.zig").BufferPoolState;

const assert = std.debug.assert;

const InputPool = @This();

const pool_size = 2;

inputs: [pool_size]Input = [_]Input{.{}} ** pool_size,
state: BufferPoolState(pool_size) = .{},

pub fn acquireAvalible(self: *InputPool) ?*Input {
    const input = if (self.state.acquireAvalible()) |index| &self.inputs[index] else null;
    if (input == null) {
        std.debug.print("avalibel input buffers: {}\n", .{self.state.avalibleBufferCount()});
    }
    return input;
}

pub fn releaseReady(self: *InputPool, input: *const Input) void {
    self.state.releaseReady(self.getIndex(input), false);
}

pub fn acquireReady(self: *InputPool) ?*const Input {
    return if (self.state.acquireReady()) |index| &self.inputs[index] else null;
}

pub fn release(self: *InputPool, input: *const Input) void {
    self.inputs[self.getIndex(input)] = .{};
    self.state.release(self.getIndex(input));
}

fn getIndex(self: *const InputPool, input: *const Input) usize {
    assert(@intFromPtr(input) >= @intFromPtr(&self.inputs));
    const index: usize = (@intFromPtr(input) - @intFromPtr(&self.inputs)) / @sizeOf(Input);
    return index;
}
