const std = @import("std");
const assert = std.debug.assert;

pub fn Vec(comptime length: comptime_int, comptime T: type) type {
    return switch (length) {
        2 => Vec2(T),
        3 => Vec3(T),
        4 => Vec4(T),
        else => @compileError(std.fmt.comptimePrint("Only vectors of length 2, 3 and 4 are suported but got : {}\n", .{length})),
    };
}

pub fn Vec2(comptime T: type) type {
    return packed struct {
        pub const Simd = @Vector(2, T);
        x: T,
        y: T,
    };
}

pub fn Vec3(comptime T: type) type {
    return packed struct {
        pub const Simd = @Vector(3, T);
        x: T,
        y: T,
        z: T,
    };
}

pub fn Vec4(comptime T: type) type {
    return packed struct {
        pub const Simd = @Vector(4, T);
        x: T,
        y: T,
        z: T,
        w: T,
    };
}

pub fn VecT(T: type) type {
    if (is_vec(T)) return T;
    comptime std.debug.assert(@typeInfo(T) == .vector);
    const len = @typeInfo(T).vector.len;
    const E = std.meta.Elem(T);
    return switch (len) {
        2 => Vec2(E),
        3 => Vec3(E),
        4 => Vec4(E),
        else => @compileError("Unsupported vector length"),
    };
}

pub fn SimdT(T: type) type {
    if (is_simd(T)) return T;
    return T.Simd;
}

pub const Color = extern struct {
    pub const Simd = @Vector(4, f32);
    r: f32 align(@alignOf(Simd)),
    g: f32,
    b: f32,
    a: f32,
};

pub fn vec(simd_vec: anytype) VecT(@TypeOf(simd_vec)) {
    return @bitCast(simd_vec);
}

pub fn simd(struct_vec: anytype) @TypeOf(struct_vec).Simd {
    return @bitCast(struct_vec);
}

pub fn is_vec(T: type) bool {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            return T == Vec(s.fields.len, ElemT(T));
        },
        else => return false,
    }
}

pub fn is_simd(T: type) bool {
    return switch (@typeInfo(T)) {
        .vector => |v| v.len >= 2 and v.len <= 4,
        else => false,
    };
}

pub fn ElemT(comptime T: type) type {
    return std.meta.fields(T)[0].type;
}

pub fn dot(a: anytype, b: @TypeOf(a)) ElemT(@TypeOf(a)) {
    if (!comptime is_vec(@TypeOf(a))) {
        @compileError("a and b must b vectors");
    }
    return @reduce(.Add, simd(a) * simd(b));
}

pub const Vec2f = Vec2(f32);
pub const Vec3f = Vec3(f32);
pub const Vec4f = Vec4(f32);
