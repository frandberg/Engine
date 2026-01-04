const std = @import("std");
const Component = @import("Component.zig");
const Signature = @import("Signature.zig");
const math = @import("math");

pub const Iterator = @import("Iterator.zig");

const root = @import("ecs.zig");
const log = root.log;

const default_chunk_size = 1024;

const World = @This();
const EntityID = root.EntityID;

pub const EntityMap = std.AutoHashMapUnmanaged(EntityID, Signature);

allocator: std.mem.Allocator,
entities: EntityMap,
arrays: Component.Arrays,
next_entity_id: EntityID,

pub fn init(allocator: std.mem.Allocator, max_entities: u32) World {
    var entities: EntityMap = .empty;
    entities.ensureTotalCapacity(allocator, max_entities) catch unreachable;

    return .{
        .allocator = allocator,
        .entities = entities,
        .arrays = Component.initArrays(allocator, 256),
        .next_entity_id = 0,
    };
}

pub fn deinit(self: *World) void {
    self.entities.deinit(self.allocator);
    Component.deinitArrays(self.allocator, &self.arrays);
}

pub fn createEntity(self: *World, components: []const Component.Component) ?EntityID {
    std.debug.assert(self.entities.capacity() >= self.entities.count());
    if (self.entities.count() == self.entities.capacity()) {
        std.log.err("Max entity limit reached: {}\n", .{self.entities.count()});
        return null;
    }

    const entity_id = self.next_entity_id;
    const signature: Signature = .encodeComponents(components);
    self.entities.put(self.allocator, entity_id, signature) catch unreachable;

    for (components) |component| {
        switch (component) {
            inline else => |c, kind| {
                const array = Component.getArrayPtr(&self.arrays, kind);
                array.add(self.allocator, entity_id, c);
            },
        }
    }
    self.next_entity_id += 1;

    return entity_id;
}

pub fn removeEntity(self: *World, entity_id: EntityID) void {
    const signature = self.entities.get(entity_id) orelse return;

    const components = signature.decode();
    for (components) |component| {
        const array = Component.getArrayPtr(&self.arrays, component);
        array.remove(entity_id);
    }
    self.entities.remove(entity_id);
}

pub fn addComponent(
    self: *World,
    entity: EntityID,
    component: Component.Component,
) void {
    const old_signature = self.entities.get(entity) orelse {
        log.warn("Tried to add {} component to entity {}, but entity does not exits\n", .{
            entity,
            switch (component) {
                inline else => |kind| @tagName(kind),
            },
        });
        return;
    };

    const new_signature = old_signature.addComponent(component);
    if (new_signature == old_signature) {
        log.warn("Entity {} already has {} component\n", .{ entity, @tagName(component) });
        return;
    }
    self.entities.put(self.allocator, entity, new_signature);

    const array = Component.getArrayPtr(&self.arrays, @tagName(component));
    array.add(self.allocator, entity, component);
}

pub fn removeComponent(self: *World, entity_id: EntityID, component_kind: Component.Kind) void {
    const old_signature = self.entities.get(entity_id) orelse return;

    const new_signature = old_signature.removeComponent(component_kind);
    self.entities.putAssumeCapacity(entity_id, new_signature);

    const array = Component.getArrayPtr(&self.arrays, component_kind);
    array.remove(entity_id);
}

pub fn getComponent(
    self: *const World,
    comptime kind: Component.Kind,
    entity_id: EntityID,
) ?Component.TypeFromKind(kind) {
    const array = Component.getArray(&self.arrays, kind);
    return if (array.getPtr(entity_id)) |c| c.* else null;
}

pub fn getComponentPtr(
    self: *World,
    comptime kind: Component.Kind,
    entity_id: EntityID,
) ?*Component.TypeFromKind(kind) {
    const array = Component.getArrayPtr(&self.arrays, kind);
    return array.getPtr(entity_id);
}

pub fn iterator(self: *const World, signature: Signature) Iterator {
    return Iterator.init(self, signature);
}
