const std = @import("std");
const assert = std.debug.assert;

pub fn Vec2(comptime T: type) type {
    return extern struct {
        pub const SimdT = @Vector(2, T);
        x: T align(@alignOf(SimdT)),
        y: T,
    };
}

pub fn Vec3(comptime T: type) type {
    return extern struct {
        pub const SimdT = @Vector(3, T);
        x: T align(@alignOf(SimdT)),
        y: T,
        z: T,
    };
}

pub fn Vec4(comptime T: type) type {
    return extern struct {
        pub const SimdT = @Vector(4, T);
        x: T align(@alignOf(SimdT)),
        y: T,
        z: T,
        w: T,
    };
}

fn VecT(SimdT: type) type {
    comptime std.debug.assert(@typeInfo(SimdT) == .vector);
    const len = @typeInfo(SimdT).vector.len;
    const ElemT = std.meta.Elem(SimdT);
    return switch (len) {
        2 => Vec2(ElemT),
        3 => Vec3(ElemT),
        4 => Vec4(ElemT),
        else => @compileError("Unsupported vector length"),
    };
}

pub fn vec(simd_vec: anytype) VecT(@TypeOf(simd_vec)) {
    return @bitCast(simd_vec);
}

pub fn simd(struct_vec: anytype) @TypeOf(struct_vec).SimdT {
    return @bitCast(struct_vec);
}

pub fn is_vec(maybe_vec: anytype) bool {
    const T = @TypeOf(maybe_vec);
    const ElemT = std.meta.fields(T)[0].type;
    const len = std.meta.fields(T).len;
    return switch (len) {
        2 => T == Vec2(ElemT),
        3 => T == Vec3(ElemT),
        3 => T == Vec4(ElemT),
        else => false,
    };
}

pub fn is_simd(maybe_simd: anytype) bool {
    return @typeInfo(@TypeOf(maybe_simd)) == .vector;
}

pub fn dot(a: anytype, b: @TypeOf(a)) @TypeOf(a) {
    if (is_vec(a)) {
        return vec(@reduce(.Add, simd(a) * simd(b)));
    }
    if (is_simd(a)) {
        return @reduce(.Add, a * b);
    }
    @compileError("non vector type in dot product");
}
