const root = @import("ecs.zig");
const World = @import("World.zig");
const Signature = @import("Signature.zig");
const EntityID = root.EntityID;

signature: Signature,
map_iter: World.EntityMap.Iterator,

pub fn init(world: *const World, signature: Signature) @This() {
    return .{
        .signature = signature,
        .map_iter = world.entities.iterator(),
    };
}

pub fn next(self: *@This()) ?EntityID {
    while (self.map_iter.next()) |entry| {
        const id = entry.key_ptr.*;
        const signature = entry.value_ptr.*;
        if (signature.bits.supersetOf(self.signature.bits)) {
            return id;
        }
    }
    return null;
}
