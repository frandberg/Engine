const std = @import("std");
const c = @cImport({
    @cInclude("mach/mach_time.h");
});

const Time = @This();

pub const RepeatingTimer = struct {};

timebase_info: c.mach_timebase_info_data_t = c.mach_timebase_info_data_t,

pub fn init() !Time {
    const timebase_info: c.mach_timebase_info_data_t = blk: {
        var info: c.mach_timebase_info_data_t = undefined;
        _ = c.mach_timebase_info(&info);
        break :blk info;
    };

    return .{
        .timebase_info = timebase_info,
    };
}

fn ticksToNS(timebase: c.mach_timebase_info_data_t, ticks: u64) f64 {
    return (@as(f64, @floatFromInt(ticks)) * @as(f64, @floatFromInt(timebase.numer))) /
        @as(f64, @floatFromInt(timebase.denom));
}
