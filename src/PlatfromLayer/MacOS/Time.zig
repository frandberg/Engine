const std = @import("std");
const c = @cImport({
    @cInclude("mach/mach_time.h");
});

const Time = @This();

timebase_info: c.mach_timebase_info_data_t,

pub const RepeatingTimer = struct {
    time: *const Time,
    start_time: u64,
    delta_time: u64,
    iteration: usize = 1,

    profile_info: ProfileInfo = .{},

    pub const ProfileInfo = struct {
        last_wait_time: f64 = 0,

        pub fn lastCycleTime(self: *const ProfileInfo) f64 {
            return self.last_wait_time - ticksToSeconds(now());
        }
    };

    pub fn initAndStart(time: *const Time, delta_time_seconds: f64) RepeatingTimer {
        return .{
            .time = time,
            .start_time = c.mach_absolute_time(),
            .delta_time = time.secondsToTicks(delta_time_seconds),
        };
    }

    pub fn wait(self: *RepeatingTimer) void {
        const wait_time = self.start_time + self.delta_time * self.iteration;
        defer _ = c.mach_wait_until(wait_time);

        std.debug.assert(wait_time >= c.mach_absolute_time());
        self.profile_info.last_wait_time = self.time.ticksToSeconds(wait_time);

        self.iteration += 1;
    }
};

pub fn init() Time {
    const timebase_info: c.mach_timebase_info_data_t = blk: {
        var info: c.mach_timebase_info_data_t = undefined;
        _ = c.mach_timebase_info(&info);
        break :blk info;
    };

    return .{
        .timebase_info = timebase_info,
    };
}

pub fn now() u64 {
    return c.mach_absolute_time();
}

pub fn nowSeconds(self: *const Time) f64 {
    return self.ticksToSeconds(now());
}

fn ticksToSeconds(self: *const Time, ticks: u64) f64 {
    return (@as(f64, @floatFromInt(ticks)) / 1_000_000_000.0) * (@as(f64, @floatFromInt(self.timebase_info.numer))) /
        @as(f64, @floatFromInt(self.timebase_info.denom));
}

fn secondsToTicks(self: *const Time, seconds: f64) u64 {
    return @as(u64, @intFromFloat(seconds * 1_000_000_000.0 * (@as(f64, @floatFromInt(self.timebase_info.denom))) /
        @as(f64, @floatFromInt(self.timebase_info.numer))));
}
