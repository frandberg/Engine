const std = @import("std");
const Input = @import("Engine").Input;

const assert = std.debug.assert;

pub const AtomicState = std.atomic.Value(State);

const InputPool = @This();

pub const State = packed struct(u8) {
    in_use_index_bits: u3 = 0,
    ready_index_bit: u3 = 0,
    _reserved: u2 = 0,
};

inputs: [3]Input = [_]Input{.{}} ** 3,
state: AtomicState = AtomicState.init(.{}),

pub fn acquireNextFreeInput(self: *InputPool) *Input {
    var old_state = self.state.load(.monotonic);
    while (true) {
        const index_bit = getNextFreeIndexBit(old_state);
        if (self.state.cmpxchgStrong(
            old_state,
            .{
                .in_use_index_bits = old_state.in_use_index_bits | index_bit,
                .ready_index_bit = old_state.ready_index_bit,
            },
            .acquire,
            .monotonic,
        )) |new_state| {
            old_state = new_state;
        } else {
            assert(index_bit != 0);
            return &self.inputs[@intCast(@ctz(index_bit))];
        }
    }
    return null;
}

pub fn releaseAndMakeReady(self: *InputPool, input: *const Input) void {
    var old_state = self.state.load(.monotonic);
    while (true) {
        const index_bit = self.getIndexBit(input);
        assert(index_bit != 0);
        assert(index_bit & old_state.ready_index_bit == 0);
        if (self.state.cmpxchgStrong(
            old_state,
            .{
                .in_use_index_bits = old_state.in_use_index_bits & ~index_bit,
                .ready_index_bit = index_bit,
            },
            .release,
            .monotonic,
        )) |new_state| {
            old_state = new_state;
        } else {
            break;
        }
    }
}

pub fn acquireReadyInput(self: *InputPool) ?*const Input {
    var old_state = self.state.load(.monotonic);
    if (old_state.ready_index_bit == 0) {
        return null;
    }
    while (true) {
        const index_bit = old_state.ready_index_bit;
        assert(index_bit != 0);
        if (self.state.cmpxchgStrong(
            old_state,
            .{
                .in_use_index_bits = old_state.in_use_index_bits | index_bit,
                .ready_index_bit = 0,
            },
            .acquire,
            .monotonic,
        )) |new_state| {
            old_state = new_state;
        } else {
            return &self.inputs[@intCast(@ctz(index_bit))];
        }
    }
}

pub fn releaseInput(self: *InputPool, input: *const Input) void {
    var old_state = self.state.load(.monotonic);
    while (true) {
        const index_bit = self.getIndexBit(input);
        assert(index_bit != 0);
        if (self.state.cmpxchgStrong(
            old_state,
            .{
                .in_use_index_bits = old_state.in_use_index_bits & ~index_bit,
                .ready_index_bit = old_state.ready_index_bit,
            },
            .release,
            .monotonic,
        )) |new_state| {
            old_state = new_state;
        } else {
            break;
        }
    }
}
fn assertStateValie(state: State) void {
    assert(@popCount(state.ready_index_bit) <= 1);
    assert(state._reserved == 0);
}

fn getNextFreeIndexBit(state: State) u3 {
    if (state.in_use_index_bits == 0b000) {
        return 0b001;
    }
    return @as(u3, 1) << @ctz(state.in_use_index_bits);
}

fn getIndexBit(self: *const InputPool, input: *const Input) u3 {
    assert(@intFromPtr(input) >= @intFromPtr(&self.inputs));
    const index: usize = (@intFromPtr(input) - @intFromPtr(&self.inputs)) / @sizeOf(Input);
    switch (index) {
        0 => return 0b001,
        1 => return 0b010,
        2 => return 0b100,
        else => @panic("Input pointer does not belong to this pool"),
    }
}
