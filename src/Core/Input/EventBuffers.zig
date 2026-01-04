const std = @import("std");

const Input = @import("Input.zig");
const Event = Input.Event;

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const Atomic = std.atomic.Value;

const EventBuffers = @This();

arenas: [2]ArenaAllocator,
buffer: ArrayList(Event) = .empty,
write_idx: Atomic(u8) = .init(0),
read_idx: Atomic(u8) = .init(0),

pub fn init(gpa: Allocator) !EventBuffers {
    const arenas = [_]ArenaAllocator{.init(gpa)} ** 2;
    return .{
        .arenas = arenas,
    };
}

pub fn deinit(self: *EventBuffers) void {
    self.arenas[0].deinit();
    self.arenas[1].deinit();
}

//Producer only (main thread)
pub fn pushEvent(self: *EventBuffers, event: Event) !void {
    const write_idx: u1 = @intCast(self.write_idx.load(.acquire));

    const allocator = self.arenas[write_idx].allocator();

    try self.buffer.append(allocator, event);
}
//Consumer only (game thread)
pub fn acquireEventBuffer(self: *EventBuffers) []const Event {
    const old_write_idx: u1 = @intCast(self.write_idx.load(.acquire));
    const new_write_idx: u1 = ~old_write_idx;

    self.write_idx.store(new_write_idx, .release);
    self.read_idx.store(old_write_idx, .release);

    const allocator = self.arenas[old_write_idx].allocator();

    return self.buffer.toOwnedSlice(allocator);
}
//Consumer only (game thread)
pub fn releaseEventBuffer(self: *EventBuffers) void {
    const read_idx: u1 = self.read_idx.load(.acquire);
    self.arenas[read_idx].reset(.retain_capacity);
}
