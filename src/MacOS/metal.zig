pub const Origin = extern struct {
    x: u64,
    y: u64,
    z: u64,
};

pub const Size = extern struct {
    width: u64,
    height: u64,
    depth: u64,
};

pub const Region = extern struct {
    origin: Origin,
    size: Size,
};
pub const PixelFormat = enum(usize) {
    Invalid = 0,
    A8Unorm = 1,
    R8Unorm = 10,
    R8Uint = 11,
    R8Sint = 12,
    R16Unorm = 20,
    R16Float = 22,
    RG8Unorm = 30,
    RG8Uint = 31,
    B5G6R5Unorm = 40,
    RGBA8Unorm = 70,
    RGBA8Unorm_sRGB = 71,
    RGBA8Uint = 73,
    BGRA8Unorm = 80,
    BGRA8Unorm_sRGB = 81,
    RGB10A2Unorm = 90,
    RG11B10Float = 92,
    RGB9E5Float = 93,
    BGR10A2Unorm = 94,
    RGBA16Float = 112,
    RGBA32Float = 123,

    // Depth/stencil
    Depth32Float = 252,
    Stencil8 = 253,
    Depth32Float_Stencil8 = 255,
}
