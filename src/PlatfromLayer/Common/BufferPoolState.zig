const std = @import("std");
const assert = std.debug.assert;
// Buffer lifecycle (triple-buffer style):
//
// Transitions:
//   free    → acquireForWrite → writing
//   writing → finishWrite     → ready
//   ready   → acquireForRead  → reading
//   reading → finishRead      → free
//
// Invariants:
//   - At most ONE buffer in READY state at a time.
//   - A buffer is either free, in use or ready (no overlap).
//   - State updates happen atomically via cmpxchg on the packed struct.
//
pub fn BufferPoolState(comptime buffer_count: comptime_int) type {
    return struct {
        const Self = @This();
        const IntT = if (buffer_count == 2) u2 else if (buffer_count == 3) u3 else @compileError("unsuported buffer count");

        const State = packed struct(u8) {
            in_use_index_bits: IntT = 0,
            ready_index_bit: IntT = 0,
            _padding: if (IntT == u2) u4 else u2 = 0,
        };

        state: std.atomic.Value(State) = std.atomic.Value(State).init(.{}),

        pub fn acquireAvalible(self: *Self) ?usize {
            var state = self.state.load(.monotonic);

            while (true) {
                assertStateValid(state);
                if (self.avalibleBufferCount() == 0) {
                    return null;
                }
                const index_bit: IntT = nextFreeIndexBit(state) orelse return null;
                assert(index_bit & state.ready_index_bit == 0);

                if (self.state.cmpxchgStrong(
                    state,
                    .{
                        .in_use_index_bits = state.in_use_index_bits | index_bit,
                        .ready_index_bit = state.ready_index_bit,
                    },
                    .acquire,
                    .monotonic,
                )) |new_state| {
                    state = new_state;
                } else {
                    return @intCast(@ctz(index_bit));
                }
            }
        }

        pub fn releaseReady(self: *Self, index: usize, discard: bool) void {
            var state = self.state.load(.monotonic);
            const index_bit = getIndexBit(index);

            while (true) {
                assertStateValid(state);
                assert(state.in_use_index_bits & index_bit != 0);
                assert(state.ready_index_bit & index_bit == 0);
                if (self.state.cmpxchgStrong(
                    state,
                    .{
                        .in_use_index_bits = state.in_use_index_bits & ~index_bit,
                        .ready_index_bit = if (discard) 0 else index_bit,
                    },
                    .release,
                    .monotonic,
                )) |new_state| {
                    state = new_state;
                } else {
                    return;
                }
            }
        }

        pub fn acquireReady(self: *Self) ?usize {
            var state = self.state.load(.monotonic);

            while (true) {
                assertStateValid(state);
                if (state.ready_index_bit == 0) {
                    return null;
                }
                if (self.state.cmpxchgStrong(
                    state,
                    .{
                        .in_use_index_bits = state.in_use_index_bits | state.ready_index_bit,
                        .ready_index_bit = 0,
                    },
                    .acquire,
                    .monotonic,
                )) |new_state| {
                    state = new_state;
                } else {
                    return @intCast(@ctz(state.ready_index_bit));
                }
            }
        }
        pub fn release(self: *Self, index: usize) void {
            var state = self.state.load(.monotonic);

            const index_bit = getIndexBit(index);

            while (true) {
                assertStateValid(state);
                assert(state.in_use_index_bits & index_bit != 0);
                assert(state.ready_index_bit & index_bit == 0);
                if (self.state.cmpxchgStrong(
                    state,
                    .{
                        .in_use_index_bits = state.in_use_index_bits & ~index_bit,
                        .ready_index_bit = state.ready_index_bit,
                    },
                    .release,
                    .monotonic,
                )) |new_state| {
                    state = new_state;
                } else {
                    return;
                }
            }
        }

        pub fn avalibleBufferCount(self: *Self) usize {
            return buffer_count - @popCount(self.state.load(.monotonic).in_use_index_bits);
        }
        fn nextFreeIndexBit(state: State) ?IntT {
            assert(state.ready_index_bit == 0 or std.math.isPowerOfTwo(state.ready_index_bit));
            assert(buffer_count != 0);
            const mask: IntT = @intCast((@as(u32, 1) << @as(u5, buffer_count)) - 1);

            const candidates: IntT = (~state.in_use_index_bits) & (~state.ready_index_bit) & mask;

            if (candidates == 0) return null;

            return candidates & (~candidates + 1);
        }
        fn assertStateValid(state: State) void {
            assert(@popCount(state.ready_index_bit) <= 1);
            assert(state.ready_index_bit & state.in_use_index_bits == 0);
            assert(state._padding == 0);
        }
        fn getIndexBit(index: usize) IntT {
            assert(index < buffer_count);
            return @intCast(@as(u4, 1) << @as(u2, @intCast(index)));
        }
    };
}
