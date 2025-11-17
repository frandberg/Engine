const std = @import("std");
const assert = std.debug.assert;
const Elem = std.meta.Elem;

pub fn VecLen(comptime VecType: type) comptime_int {
    comptime assert(@typeInfo(VecType) == .vector);
    return @typeInfo(VecType).vector.len;
}

pub fn splat(scalar: anytype, len: comptime_int) @Vector(len, @TypeOf(scalar)) {
    return @splat(scalar);
}

pub fn dot(v1: anytype, v2: anytype) Elem(@TypeOf(v1)) {
    comptime {
        assert(Elem(@TypeOf(v1)) == Elem(@TypeOf(v2)));
        assert(VecLen(@TypeOf(v1)) == VecLen(@TypeOf(v2)));
    }
    return @reduce(.Add, v1 * v2);
}

pub fn normalize(vec: anytype) @TypeOf(vec) {
    const len = std.math.sqrt(dot(vec, vec));
    return vec / splat(len, VecLen(@TypeOf(vec)));
}
