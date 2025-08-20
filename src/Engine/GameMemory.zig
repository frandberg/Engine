const std = @import("std");

pub const GameMemory = extern struct {
    pub const permanent_storage_size: u64 = 64 * 1024 * 1024; // 64 MiB

    permanent_storage: *anyopaque,
    pub fn init(allocator: std.mem.Allocator) !GameMemory {
        const permanent_storage = try allocator.alignedAlloc(
            u8,
            std.heap.pageSize(),
            permanent_storage_size,
        );
        return .{
            .permanent_storage = permanent_storage.ptr,
        };
    }

    pub fn deinit(self: GameMemory, allocator: std.mem.Allocator) void {
        allocator.free(@as([*]u8, @ptrCast(self.permanent_storage))[0..permanent_storage_size]);
    }
};
