const std = @import("std");
const math = @import("math");
const utils = @import("utils");

const core = @import("core");

const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ColorSprite = core.Graphics.ColorSprite;

const root = @import("ecs.zig");
const EntityID = root.EntityID;

const max_chunks = 10;

const Signature = @import("Signature.zig");

pub const Component = union(enum) {
    transform: math.Transform2D,
    color_sprite: ColorSprite,
};

pub const Kind = std.meta.FieldEnum(Component);
pub const KindCount = std.meta.fields(Component).len;

pub fn componentIndex(kind: Kind) usize {
    return switch (kind) {
        inline else => |k| std.meta.fieldIndex(Component, @tagName(k)).?,
    };
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

            pub fn init(allocator: std.mem.Allocator, size: usize) Chunk {
                var elements: SoA = .empty;
                elements.ensureTotalCapacity(allocator, size) catch unreachable;
                return .{
                    .elements = elements,
                };
            }

            pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
                self.elements.deinit(allocator);
            }

            inline fn getIndex(self: *const @This(), entity: EntityID) ?usize {
                for (self.elements.items(.entity), 0..) |e, i| {
                    if (e == entity) {
                        return i;
                    }
                }
                return null;
            }

            pub fn isFull(self: @This()) bool {
                return self.elements.len == self.elements.capacity;
            }

            pub fn getPtr(self: *const @This(), entity: EntityID) ?*T {
                const index = self.getIndex(entity) orelse return null;
                return &self.elements.items(.component)[index];
            }

            pub fn add(self: *@This(), entity: EntityID, component: T) void {
                assert(!self.isFull());

                self.elements.appendAssumeCapacity(.{
                    .entity = entity,
                    .component = component,
                });
            }

            pub fn remove(self: *@This(), entity: EntityID) void {
                const index = self.getIndex(entity).?;
                self.elements.swapRemove(index);
            }
        };

        const ChunkIndexMap = std.AutoHashMapUnmanaged(EntityID, usize);

        chunks: [max_chunks]Chunk,
        chunk_count: usize,
        chunk_indices: ChunkIndexMap,
        chunk_size: usize,

        pub fn init(allocator: std.mem.Allocator, chunk_size: usize) @This() {
            var chunks: [max_chunks]Chunk = undefined;
            chunks[0] = .init(allocator, chunk_size);

            return .{
                .chunks = chunks,
                .chunk_count = 1,
                .chunk_indices = .empty,
                .chunk_size = chunk_size,
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            for (self.chunks[0..self.chunk_count]) |*chunk| {
                chunk.deinit(allocator);
            }
            self.chunk_indices.deinit(allocator);
        }

        inline fn findFirstAvalibleChunk(self: *@This()) ?usize {
            for (&self.chunks[0..self.chunk_count], 0..) |*chunk, i| {
                if (!chunk.isFull()) {
                    return i;
                }
            }
            return null;
        }

        pub fn add(
            self: *@This(),
            allocator: Allocator,
            entity: EntityID,
            component: T,
        ) void {
            const index = blk: for (self.chunks[0..self.chunk_count], 0..) |chunk, i| {
                if (!chunk.isFull()) {
                    break :blk i;
                }
            } else {
                self.addChunk(allocator);
                break :blk self.chunk_count - 1;
            };

            const chunk: *Chunk = &self.chunks[index];
            self.chunk_indices.put(allocator, entity, chunk.elements.len) catch unreachable;
            chunk.add(entity, component);
        }

        pub fn remove(self: *@This(), entity: EntityID) void {
            std.debug.print("removing entity: {} from array\n", .{entity});
            const chunk_index = self.chunk_indices.get(entity) orelse return;
            self.chunks[chunk_index].remove(entity);
            self.chunk_indices.remove(entity);
        }

        pub inline fn getPtr(self: *const @This(), entity: EntityID) ?*T {
            const chunk_index = self.chunk_indices.get(entity) orelse return null;
            return self.chunks[chunk_index].getPtr(entity);
        }
        fn addChunk(self: *@This(), allocator: Allocator) void {
            self.chunks[self.chunk_count] = .init(allocator, self.chunk_size);
            self.chunk_count += 1;
        }
    };
}

const arrays_fields: [KindCount]std.builtin.Type.StructField = blk: {
    var fields: [KindCount]std.builtin.Type.StructField = undefined;
    for (std.meta.fields(Component), 0..) |field, i| {
        fields[i] = .{
            .name = field.name,
            .type = Array(field.type),
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(field.type),
        };
    }
    break :blk fields;
};

pub const Arrays = @Type(.{ .@"struct" = .{
    .fields = &arrays_fields,
    .layout = .auto,
    .is_tuple = false,
    .decls = &.{},
} });

pub fn TypeFromKind(comptime kind: Kind) type {
    const index = comptime componentIndex(kind);
    const fields = std.meta.fields(Component);
    return fields[index].type;
}

pub fn initArrays(allocator: std.mem.Allocator, chunk_size: usize) Arrays {
    var arrays: Arrays = undefined;
    inline for (comptime std.meta.fields(Component)) |field| {
        @field(&arrays, field.name) = Array(field.type).init(allocator, chunk_size);
    }
    return arrays;
}

pub fn deinitArrays(allocator: std.mem.Allocator, arrays: *Arrays) void {
    inline for (comptime std.meta.fieldNames(Component)) |name| {
        @field(arrays, name).deinit(allocator);
    }
}

pub inline fn getArrayPtr(arrays: *Arrays, comptime kind: Kind) *Array(TypeFromKind(kind)) {
    return &@field(arrays, @tagName(kind));
}

pub inline fn getArray(arrays: *const Arrays, comptime kind: Kind) Array(TypeFromKind(kind)) {
    return @field(arrays, @tagName(kind));
}
