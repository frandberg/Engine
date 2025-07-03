const std = @import("std");
const objc = @import("objc");

const cg = @import("CoreGraphics");
const buitin = @import("builtin");
const ptr_bit_width = buitin.target.ptrBitWidth();

pub const UInteger = if (ptr_bit_width == 64) u64 else if (ptr_bit_width) u32 else @compileError("non standard ptr bit width");
pub const Integer = if (ptr_bit_width == 64) i64 else if (ptr_bit_width) i32 else @compileError("non standard ptr bit width");

pub const Rect = cg.Rect;

pub const Object = @import("Object.zig");

pub const String = @import("String.zig");
pub const Date = @import("Date.zig");
