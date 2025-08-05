const std = @import("std");

pub const OffscreenBufferBGRA8 = extern struct {
    memory: [*]u32,
    width: u32,
    height: u32,
};

pub const IntiGameMemoryFn = fn (game_memory: *const GameMemory) callconv(.c) void;
pub const UpdateAndRenderFn = fn (offscreen_buffer: ?*const OffscreenBufferBGRA8, game_memory: *const GameMemory, delta_time_s: f64) callconv(.c) void;

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

pub fn updateAndRenderStub(_: ?*const OffscreenBufferBGRA8, _: *const GameMemory, _: f64) callconv(.c) void {}
pub fn IntiGameMemoryStub(_: *const GameMemory) callconv(.c) void {}
