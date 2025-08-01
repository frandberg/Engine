const std = @import("std");

pub const OffscreenBufferBGRA8 = extern struct {
    memory: [*]u32,
    width: u32,
    height: u32,
};

pub const IntiGameMemoryFn = fn (game_memory: *const GameMemory) callconv(.c) void;
pub const UpdateAndRenderFn = fn (c_buffer: *const OffscreenBufferBGRA8, game_memory: *const GameMemory, delta_time_s: f64) callconv(.c) void;

pub const GameMemory = extern struct {
    // pub const permanent_storage_size: u64 = 64 * 1024 * 1024; // 64 MiB
    pub const permanent_storage_size: u64 = @sizeOf(GameMemory);
    // pub const transient_storage_size: u64 = 4 * 1024 * 1024 * 1024; // 4 GiB
    permanent_storage: *anyopaque,
    // transient_storage: *anyopaque,
};

pub fn updateAndRenderStub(_: *const OffscreenBufferBGRA8, _: *const GameMemory, _: f64) callconv(.c) void {}
pub fn IntiGameMemoryStub(_: *const GameMemory) callconv(.c) void {}
