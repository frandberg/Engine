const std = @import("std");
const math = @import("math.zig");
const Physics = @import("../Physics/Physics.zig");
const Sprite = @import("../Sprite.zig");
const utils = @import("utils");

const PhysicsComponents = @import("Components/PhysicComponents.zig");
const RendererComponents = @import("Components/RendererComponents.zig");

const root = @import("ecs.zig");
const EntityID = root.EntityID;

const Signature = @import("Signature.zig");

pub const Component = union(enum) {
    transform: math.Transform2D,
    rigid_body: PhysicsComponents.RigidBody2D,
    color_sprite: RendererComponents.ColorSprite,
};

pub const Kind = std.meta.FieldEnum(Component);
pub const KindCount = std.meta.fields(Component).len;

fn componentIndex(component: Kind) usize {
    std.meta.fieldIndex(Kind, @tagName(component));
}

pub fn Array(comptime T: type) type {
    return struct {
        pub const Chunk = struct {
            pub const Element = struct {
                entity: EntityID,
                component: T,
            };

            const SoA = std.MultiArrayList(Element);

            elements: SoA,

            pub fn init(allocator: std.mem.Allocator, size: usize) !Chunk {
                const elements: SoA = .empty;
                try elements.ensureTotalCapacity(allocator, size);
                return .{
                    .elements = elements,
                };
            }

            pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
                self.elements.deinit(allocator);
            }

            inline fn getIndex(self: *@This(), entity: EntityID) ?usize {
                for (self.elements.slice(.entity)[0..self.count], 0..) |e, i| {
                    if (e == entity) {
                        return i;
                    }
                }
                return null;
            }

            pub fn isFull(self: *@This()) bool {
                return self.elements.len == self.elements.capacity;
            }

            pub fn get(self: *@This(), entity: EntityID) ?*T {
                const index = self.getIndex(entity) orelse return null;
                return self.elements.slice(.component)[index];
            }

            pub fn add(self: *@This(), entity: EntityID, component: T) void {
                std.debug.assert(!self.isFull());
                self.elements.append(.{
                    .entity = entity,
                    .component = component,
                }) catch @panic("OOM But capacity should be ensured!");
            }

            pub fn remove(self: *@This(), entity: EntityID) void {
                const index = self.getIndex(entity).?;
                self.elements.swapRemove(index);
            }
        };

        const ChunkIndexMap = std.AutoHashMapUnmanaged(EntityID, usize);

        chunks: []Chunk,
        chunk_indices: ChunkIndexMap,
        chunk_size: usize,
        avalible_chunk_index: usize,

        pub fn init(chunk_size: usize) Array {
            return .{
                .chunks = &.{},
                .chunk_indices = .empty,
                .chunk_capacity = chunk_size,
                .first_avalible_chunk = 0,
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            for (self.chunks) |chunk| {
                chunk.deinit(allocator);
            }
            self.chunk_indices.deinit(allocator);
        }

        inline fn findFirstAvalibleChunk(self: *@This()) usize {
            for (self.chunks, 0..) |chunk, i| {
                if (!chunk.isFull()) {
                    return i;
                }
            }
            return self.chunks.len;
        }

        pub fn add(
            self: *@This(),
            allocator: std.mem.Allocator,
            entity: EntityID,
            component: T,
        ) void {
            const index = self.avalible_chunk_index;

            if (index == self.chunks.len) {
                self.chunks[index] = Chunk.init(allocator, self.chunk_size);
            }

            const chunk = self.chunks[index];
            self.chunk_indices.put(allocator, entity, chunk.elements.len) catch unreachable;
            chunk.add(entity, component);

            if (chunk.isFull()) {
                self.avalible_chunk_index = self.findFirstAvalibleChunk();
            }
        }

        pub fn remove(self: *@This(), entity: EntityID) void {
            const chunk_index = self.chunk_indices.get(entity) orelse return;
            self.chunks[chunk_index].remove(entity);
            self.chunk_indices.remove(entity);
            self.avalible_chunk_index = self.findFirstAvalibleChunk();
        }

        pub inline fn get(self: *@This(), entity: EntityID) ?T {
            return self.getPtr(entity).?;
        }

        pub inline fn getPtr(self: *@This(), entity: EntityID) ?*T {
            const chunk_index = self.chunk_indices.get(entity) orelse return null;
            return self.chunks[chunk_index].get(entity);
        }
    };
}

const arrays_fields: [KindCount]std.builtin.Type.StructField = blk: {
    var fields: [KindCount]std.builtin.Type.StructField = undefined;
    for (std.meta.fieldInfo(Component), 0..) |field, i| {
        fields[i] = .{
            .name = field.name,
            .type = Array(field.type),
        };
    }
    break :blk fields;
};

pub const Arrays = @Type(.{ .@"struct" = .{
    .fields = arrays_fields,
    .layout = .auto,
    .is_tuple = false,
    .decls = &.{},
} });

fn TypeFromKind(kind: Kind) type {
    return @TypeOf(@field(Component, @tagName(kind)));
}

pub fn initArrays(chunk_size: usize) Arrays {
    var arrays: Arrays = undefined;
    inline for (comptime std.meta.fieldInfo(Component)) |field| {
        @field(&arrays, field.name) = Array(field.type).init(chunk_size);
    }
    return arrays;
}

pub fn deinitArrays(allocator: std.mem.Allocator, arrays: *Arrays) void {
    inline for (comptime std.meta.fieldNames(Component)) |name| {
        @field(arrays, name).deinit(allocator);
    }
}

pub inline fn getArray(arrays: Arrays, kind: Kind) Array(TypeFromKind(kind)) {
    return @field(arrays, @tagName(kind));
}
