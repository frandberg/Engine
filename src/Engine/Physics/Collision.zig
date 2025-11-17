const std = @import("std");
const math = @import("math");
const Mat3f = math.Mat3f;
const Vec2f = math.Vec2f;
const Transform2D = math.Transform2D;

const RigidBody = @import("RigidBody.zig");

const float_eps = std.math.floatEps(f32);
const Rect = math.Rect;

const splat = math.Vector.splat;

const VecLen = std.simd.suggestVectorLength(f32) orelse @compileError("No SIMD support for f32");
const Vecf = @Vector(VecLen, f32);

pub fn rectAabb(rect: Rect, transform: math.Mat3f) Aabb {
    const corners: [4]Mat3f.VecT = .{
        @bitCast(transform.mulVec(.{ rect.half_width, rect.half_height, 1.0 })),
        @bitCast(transform.mulVec(.{ rect.half_width, -rect.half_height, 1.0 })),
        @bitCast(transform.mulVec(.{ -rect.half_width, rect.half_height, 1.0 })),
        @bitCast(transform.mulVec(.{ -rect.half_width, -rect.half_height, 1.0 })),
    };
    var max: Vec2f = .{ .x = -std.math.inf(f32), .y = -std.math.inf(f32) };
    var min: Vec2f = .{ .x = std.math.inf(f32), .y = std.math.inf(f32) };

    inline for (corners) |corner| {
        if (corner[0] < min.x) min.x = corner[0];
        if (corner[1] < min.y) min.y = corner[1];

        if (corner[0] > max.x) max.x = corner[0];
        if (corner[1] > max.y) max.y = corner[1];
    }

    return .{
        .max = max,
        .min = min,
    };
}

pub const Aabb = struct {
    max: Vec2f,
    min: Vec2f,
};

pub const CollisionBatch = struct {
    max_x: Vecf,
    min_x: Vecf,
    max_y: Vecf,
    min_y: Vecf,
    vel_x: Vecf,
    vel_y: Vecf,
};

pub fn aabbIsColliding(a: Aabb, b: Aabb) bool {
    if (a.max.x < b.min.x or a.min.x > b.max.x or
        a.max.y < b.min.y or a.min.y > b.max.y)
    {
        return false;
    }
    return true;
}

pub fn sweptAabbCollisionTime(
    a: Aabb,
    b: Aabb,
    vel_a: Vec2f,
    vel_b: Vec2f,
    time_step: f32,
) ?f32 {
    // Compute relative velocity
    const vel_rel = Vec2f{
        .x = vel_a.x - vel_b.x,
        .y = vel_a.y - vel_b.y,
    };

    if (aabbIsColliding(a, b)) {
        return -1.0;
    }

    var entry = (Vec2f{ .x = 0, .y = 0 }).toSimd();
    var exit = (Vec2f{ .x = 0, .y = 0 }).toSimd();

    // For each axis (x=0, y=1)
    inline for (.{ 0, 1 }) |i| {
        const av_min = if (i == 0) a.min.x else a.min.y;
        const av_max = if (i == 0) a.max.x else a.max.y;
        const bv_min = if (i == 0) b.min.x else b.min.y;
        const bv_max = if (i == 0) b.max.x else b.max.y;

        const v = if (i == 0) vel_rel.x else vel_rel.y;

        if (v > 0.0) {
            // moving positive → entering at b.min - a.max
            entry[i] = (bv_min - av_max) / v;
            exit[i] = (bv_max - av_min) / v;
        } else if (v < 0.0) {
            // moving negative → entering at b.max - a.min
            entry[i] = (bv_max - av_min) / v;
            exit[i] = (bv_min - av_max) / v;
        } else {
            // No movement on this axis:
            // if they don't overlap now → no collision ever
            if (av_max <= bv_min or av_min >= bv_max) {
                return null;
            }
            entry[i] = -std.math.inf(f32);
            exit[i] = std.math.inf(f32);
        }
    }

    const entry_time = @max(entry[0], entry[1]);
    const exit_time = @min(exit[0], exit[1]);

    // Reject collision if:
    if (entry_time > exit_time) return null; // no interval overlap
    if (exit_time <= 0.0) return null; // collision happened in the past
    if (entry_time > time_step) return null; // beyond this frame

    return entry_time;
}
fn projectAabbOnNormal(a: Aabb, n: Vec2f) struct { min: f32, max: f32 } {
    const corners = [_]Vec2f{
        .{ .x = a.min.x, .y = a.min.y },
        .{ .x = a.min.x, .y = a.max.y },
        .{ .x = a.max.x, .y = a.min.y },
        .{ .x = a.max.x, .y = a.max.y },
    };

    var p_min = std.math.inf(f32);
    var p_max = -std.math.inf(f32);

    inline for (corners) |c| {
        const p = c.dot(n);
        if (p < p_min) p_min = p;
        if (p > p_max) p_max = p;
    }

    return .{ .min = p_min, .max = p_max };
}

pub fn sweptAabbLineCollisionTime(
    aabb: Aabb,
    line: Mat3f,
    vel_aabb: Vec2f,
    vel_line: Vec2f,
    time_step: f32,
) ?f32 {
    // 1) Line geometry from transform
    const point = Vec2f.fromSimd(line.mulVec(.{ 0.0, 0.0, 1.0 }));

    // normal = rotated (0,1), no translation (w = 0)
    var normal = Vec2f.fromSimd(line.mulVec(.{ 0.0, 1.0, 0.0 }));
    const len2 = normal.dot(normal);
    if (len2 < float_eps) return null; // degenerate transform
    normal = normal.scale(1.0 / @sqrt(len2));

    // line equation: n·x = d
    const distance = normal.dot(point);

    // 2) Project AABB onto normal
    const proj = projectAabbOnNormal(aabb, normal); // proj.min, proj.max

    // Convert to signed distances to the line
    const s_min = proj.min - distance;
    const s_max = proj.max - distance;

    // 3) Relative velocity along normal
    const vel_rel = Vec2f{
        .x = vel_aabb.x - vel_line.x,
        .y = vel_aabb.y - vel_line.y,
    };
    const vel_rel_normal = vel_rel.dot(normal);

    if (s_min <= 0.0 and s_max >= 0.0) {
        if (vel_rel_normal < 0.0 and s_min >= 0.0) return -1.0; // pushing downwards into line
        if (vel_rel_normal > 0.0 and s_max <= 0.0) return -1.0; // pushing upwards into line

        // touching but moving away or tangent → fine
        return null;
    }

    if (@abs(vel_rel_normal) < float_eps) {
        // Moving parallel to the line → never cross
        return null;
    }

    var time: f32 = undefined;

    if (s_max < 0.0 and vel_rel_normal > 0.0) {
        // Box is entirely on the "negative" side, moving toward positive
        // Closest point is s_max (the one nearest to 0)
        time = -s_max / vel_rel_normal;
    } else if (s_min > 0.0 and vel_rel_normal < 0.0) {
        // Box is entirely on the "positive" side, moving toward negative
        time = -s_min / vel_rel_normal;
    } else {
        // Moving away, or box straddles the line in a weird way (shouldn't happen)
        return null;
    }

    if (time < 0.0 or time > time_step) return null;
    return time;
}

pub fn sweptRigidBodyCollision(rb_a: RigidBody, rb_b: RigidBody, transform_a: Mat3f, transform_b: Mat3f, time_step: f32) ?f32 {
    return switch (rb_a.shape) {
        .rect => |rect_a| switch (rb_b.shape) {
            .rect => |rect_b| sweptAabbCollisionTime(
                rectAabb(rect_a, transform_a),
                rectAabb(rect_b, transform_b),
                rb_a.velocity,
                rb_b.velocity,
                time_step,
            ),
            .line => sweptAabbLineCollisionTime(
                rectAabb(rect_a, transform_a),
                transform_b,
                rb_a.velocity,
                rb_b.velocity,
                time_step,
            ),
        },
        .line => switch (rb_b.shape) {
            .rect => |rect_b| sweptAabbLineCollisionTime(
                rectAabb(rect_b, transform_b),
                transform_a,
                rb_b.velocity,
                rb_a.velocity,
                time_step,
            ),
            .line => @panic("unsuported collision line-line"), // line-line collision not handled
        },
    };
}

const CollisionResult = struct {
    time: f32,
    pair: IndexPair,
};

pub const IndexPair = struct {
    a: usize,
    b: usize,
};

// NOTE Negative time indicates that the to objects where already overlapping, this should be resolved before steping further
pub fn firstCollisionTime(rigid_bodies: []const RigidBody, transforms: []const Mat3f, index_buffer: []const IndexPair, time_step: f32) ?CollisionResult {
    var result: ?CollisionResult = null;
    for (index_buffer) |indices| {
        if (sweptRigidBodyCollision(
            rigid_bodies[indices.a],
            rigid_bodies[indices.b],
            transforms[indices.a],
            transforms[indices.b],
            time_step,
        )) |collision_time| {
            if (result) |*r| {
                if (collision_time < r.time) {
                    r.time = collision_time;
                    r.pair = indices;
                }
            } else {
                result = .{
                    .time = collision_time,
                    .pair = indices,
                };
            }
        }
    }
    return result;
}
pub fn generateTestData(
    allocator: std.mem.Allocator,
    body_count: usize,
) !struct {
    rigid_bodies: []RigidBody,
    transforms: []Mat3f,
    index_buffer: [][2]usize,
} {
    var prng = std.Random.DefaultPrng.init(1234567); // fixed seed
    const rnd = prng.random();

    // 1) Bodies
    const bodies = try allocator.alloc(RigidBody, body_count);
    const transforms = try allocator.alloc(Mat3f, body_count);

    const world_radius: f32 = 1000.0;
    const min_half_size: f32 = 0.2;
    const max_half_size: f32 = 3.0;
    const max_speed: f32 = 20.0;

    for (bodies, 0..) |*rb, i| {
        const px = (rnd.float(f32) * 2.0 - 1.0) * world_radius;
        const py = (rnd.float(f32) * 2.0 - 1.0) * world_radius;

        const hx = min_half_size + rnd.float(f32) * (max_half_size - min_half_size);
        const hy = min_half_size + rnd.float(f32) * (max_half_size - min_half_size);

        const vx = (rnd.float(f32) * 2.0 - 1.0) * max_speed;
        const vy = (rnd.float(f32) * 2.0 - 1.0) * max_speed;

        rb.* = .{
            .shape = .{ .rect = .{
                .half_width = hx,
                .half_height = hy,
            } },
            .velocity = .{
                .x = vx,
                .y = vy,
            },
            .acceleration = .{
                .x = 0.0,
                .y = 0.0,
            },

            // other fields if you have them…
        };

        // identity + translation Mat3f (assuming row-major)
        transforms[i] = Mat3f{
            .m = .{
                .{ 1.0, 0.0, px },
                .{ 0.0, 1.0, py },
                .{ 0.0, 0.0, 1.0 },
            },
        };
    }

    // 2) Index buffer – simplest is all unique pairs i<j
    const pair_count = body_count * (body_count - 1) / 2;
    var indices = try allocator.alloc([2]usize, pair_count);

    var k: usize = 0;
    var i: usize = 0;
    while (i < body_count) : (i += 1) {
        var j: usize = i + 1;
        while (j < body_count) : (j += 1) {
            indices[k] = .{ i, j };
            k += 1;
        }
    }
    std.debug.assert(k == pair_count);

    return .{
        .rigid_bodies = bodies,
        .transforms = transforms,
        .index_buffer = indices,
    };
}
test "collision" {}
