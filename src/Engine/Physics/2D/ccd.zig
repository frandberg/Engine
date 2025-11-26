const std = @import("std");
const AABB = @import("AABB.zig");
const math = @import("math");
const Vec2f = math.Vec2f;
const Mat3f = math.Mat3f;
const assert = std.debug.assert;

const ecs = @import("ecs");

const f_max = std.math.floatMax(f32);
const inf = std.math.inf(f32);
const RigidBody = @import("RigidBody.zig");

const VecLen = std.simd.suggestVectorLength(f32) orelse @compileError("No SIMD support for f32 on this target");

pub const VecT = @Vector(VecLen, f32);

pub const IndexPair = struct {
    a: usize,
    b: usize,
};

const Result = struct {
    index_pair: IndexPair = .{
        .a = std.math.maxInt(usize),
        .b = std.math.maxInt(usize),
    },
    time: f32 = inf,
};

pub fn firstCollisionTime(allocator: std.mem.Allocator, rigid_bodies: []const RigidBody, transforms: []const math.Transform2D, index_pairs: []const IndexPair, time_step: f32) ?Result {
    assert(rigid_bodies.len < std.math.maxInt(usize));
    const aabbs: []AABB = allocator.alloc(AABB, rigid_bodies.len) catch unreachable;
    defer allocator.free(aabbs);

    for (rigid_bodies, transforms, 0..) |body, transform, i| {
        aabbs[i] = RigidBody.rectAabb(body.shape.rect, transform.toMat3());
    }
    var result: Result = .{};

    var a: AabbCollisionData = undefined;
    var b: AabbCollisionData = undefined;
    var index_pairs_in_vecs: [VecLen]IndexPair = undefined;
    for (index_pairs, 0..) |indices, i| {
        const vec_idx = i % VecLen;
        a.addAabb(aabbs[indices.a], rigid_bodies[indices.a].velocity, vec_idx);
        b.addAabb(aabbs[indices.b], rigid_bodies[indices.b].velocity, vec_idx);
        index_pairs_in_vecs[vec_idx] = indices;
        if (vec_idx == VecLen - 1) {
            const new_result = aabbVsAabb(a, b);
            if (new_result.time < result.time) {
                result.time = new_result.time;
                result.index_pair = index_pairs_in_vecs[new_result.index];
            }
        }
    }
    if (index_pairs.len % VecLen != 0) {
        var vec_idx = index_pairs.len % VecLen;
        const first_dummy = vec_idx;
        while (vec_idx < VecLen) : (vec_idx += 1) {
            a.addDummyData(vec_idx);
            b.addDummyData(vec_idx);
        }
        const new_result = aabbVsAabb(a, b);
        if (new_result.time < result.time) {
            assert(new_result.index < first_dummy);
            result.time = new_result.time;
            result.index_pair = index_pairs_in_vecs[new_result.index];
        }
    }
    assert(result.time >= 0.0);

    std.debug.print("first collision: {}\n", .{result.time});

    return if (result.time <= time_step) result else null;
}

pub const AabbCollisionData = struct {
    pub const Axis = struct {
        max: VecT,
        min: VecT,
        vel: VecT,
    };

    x: Axis,
    y: Axis,

    pub fn addAabb(self: *@This(), aabb: AABB, vel: Vec2f, index: usize) void {
        assert(index < @typeInfo(VecT).vector.len);
        self.x.max[index] = aabb.max.x;
        self.y.max[index] = aabb.max.y;
        self.x.min[index] = aabb.min.x;
        self.y.min[index] = aabb.min.y;
        self.x.vel[index] = vel.x;
        self.y.vel[index] = vel.y;
    }

    pub fn addDummyData(self: *@This(), index: usize) void {
        self.x.max[index] = -f_max;
        self.y.max[index] = -f_max;
        self.x.min[index] = f_max;
        self.y.min[index] = f_max;
        self.x.vel[index] = 0.0;
        self.y.vel[index] = 0.0;
    }
};

const zero_vec: VecT = @splat(0.0);
const inf_vec: VecT = @splat(inf);
const neg_inf_vec: VecT = @splat(-inf);
inline fn entryExitTime(a: AabbCollisionData.Axis, b: AabbCollisionData.Axis) struct {
    entry: VecT,
    exit: VecT,
} {
    const rel_vel = a.vel - b.vel;
    const rel_vel_pos: @Vector(VecLen, bool) = rel_vel > @as(VecT, @splat(0.0));
    const rel_vel_zero = rel_vel == zero_vec;

    const dist_1 = b.min - a.max;
    const dist_2 = b.max - a.min;

    const near = @select(f32, rel_vel_pos, dist_1, dist_2);
    const far = @select(f32, rel_vel_pos, dist_2, dist_1);

    const entry_raw = near / rel_vel;
    const exit_raw = far / rel_vel;

    // Fix NaN → ∞ (0/0 case)
    const entry_nan = entry_raw != entry_raw;
    const exit_nan = exit_raw != exit_raw;
    const entry_not_nan = @select(f32, entry_nan, inf_vec, entry_raw);
    const exit_not_nan = @select(f32, exit_nan, inf_vec, exit_raw);

    // Overlap test for stationary case
    const overlapping = (a.min <= b.max) & (a.max >= b.min);

    // Case B1: rel_vel == 0 AND overlapping  → no constraint: [-∞, +∞]
    const entry_overlap = @select(f32, overlapping, neg_inf_vec, inf_vec);
    const exit_overlap = @select(f32, overlapping, inf_vec, neg_inf_vec);

    // Select correct behavior
    const entry = @select(f32, rel_vel_zero, entry_overlap, entry_not_nan);
    const exit = @select(f32, rel_vel_zero, exit_overlap, exit_not_nan);

    return .{
        .entry = entry,
        .exit = exit,
    };
}

const VecResult = struct {
    time: f32 = inf,
    index: usize = std.math.maxInt(usize),
};
const BoolVec = @Vector(VecLen, bool);
pub fn aabbVsAabb(a: AabbCollisionData, b: AabbCollisionData) VecResult {
    const ex_x = entryExitTime(a.x, b.x);
    const ex_y = entryExitTime(a.y, b.y);

    const entry: VecT = @max(ex_x.entry, ex_y.entry);
    const exit: VecT = @min(ex_x.exit, ex_y.exit);

    // invalid if interval ended at/ before now
    const exit_not_future = exit <= zero_vec; // <= is the key change
    const exit_before_entry = exit < entry;

    const collision_invalid = exit_not_future | exit_before_entry;

    // only clamp negative entry for lanes that are NOT invalid
    const entry_clamped = @select(
        f32,
        (entry < zero_vec) & !collision_invalid,
        zero_vec,
        entry,
    );

    const final_times = @select(f32, collision_invalid, inf_vec, entry_clamped);

    var result: VecResult = .{};
    inline for (0..VecLen) |i| {
        if (final_times[i] < result.time) {
            result.time = final_times[i];
            result.index = i;
        }
    }
    return result;
}
