const std = @import("std");

pub fn BiMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const emtpy: Self = .{};

        pub const ForwardMap = std.AutoHashMapUnmanaged(K, V);
        pub const ReverseMap = std.AutoHashMapUnmanaged(V, K);

        forward: ForwardMap = .{},
        reverse: ReverseMap = .{},

        // ============================================================
        // Initialization / Memory Management
        // ============================================================

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.forward.deinit(allocator);
            self.reverse.deinit(allocator);
        }

        pub fn clear(self: *Self) void {
            self.forward.clear();
            self.reverse.clear();
        }

        pub fn clearAndFree(self: *Self, allocator: std.mem.Allocator) void {
            self.forward.clearAndFree(allocator);
            self.reverse.clearAndFree(allocator);
        }

        // ============================================================
        // Capacity Management
        // ============================================================

        pub fn ensureTotalCapacity(self: *Self, allocator: std.mem.Allocator, cap: usize) !void {
            try self.forward.ensureTotalCapacity(allocator, cap);
            try self.reverse.ensureTotalCapacity(allocator, cap);
        }

        pub fn ensureUnusedCapacity(self: *Self, allocator: std.mem.Allocator, needed: usize) !void {
            try self.forward.ensureUnusedCapacity(allocator, needed);
            try self.reverse.ensureUnusedCapacity(allocator, needed);
        }

        pub fn capacity(self: *Self) usize {
            // Forward and reverse always have identical capacity.
            return self.forward.capacity();
        }

        pub fn count(self: *Self) usize {
            return self.forward.count();
        }

        pub fn load(self: *Self) f64 {
            return self.forward.load();
        }

        // ============================================================
        // PUT
        // ============================================================

        pub fn put(self: *Self, allocator: std.mem.Allocator, key: K, value: V) !void {
            // Remove old forward entry if any
            if (self.forward.get(key)) |old_value| {
                _ = self.reverse.remove(old_value);
            }

            // Remove old reverse entry if any
            if (self.reverse.get(value)) |old_key| {
                _ = self.forward.remove(old_key);
            }

            try self.forward.put(allocator, key, value);
            try self.reverse.put(allocator, value, key);
        }

        pub fn putAssumingCapacity(self: *Self, key: K, value: V) void {
            if (self.forward.get(key)) |old_value| {
                _ = self.reverse.remove(old_value);
            }
            if (self.reverse.get(value)) |old_key| {
                _ = self.forward.remove(old_key);
            }

            self.forward.putAssumeCapacity(key, value);
            self.reverse.putAssumeCapacity(value, key);
        }

        // ============================================================
        // GET OR PUT
        // ============================================================

        pub fn getOrPut(
            self: *Self,
            allocator: std.mem.Allocator,
            key: K,
        ) !struct { entry: *V, found: bool } {
            const res = try self.forward.getOrPut(allocator, key);

            if (res.found) {
                return .{ .entry = res.entry, .found = true };
            }

            // Insert new key→value; user must assign *res.entry after calling
            return .{ .entry = res.entry, .found = false };
        }

        pub fn getOrPutAssumeCapacity(
            self: *Self,
            key: K,
        ) struct { entry: *V, found: bool } {
            const res = self.forward.getOrPutAssumeCapacity(key);

            if (res.found) return res;

            return .{ .entry = res.entry, .found = false };
        }

        // Reverse side
        pub fn getOrPutReverse(
            self: *Self,
            allocator: std.mem.Allocator,
            value: V,
        ) !struct { entry: *K, found: bool } {
            const res = try self.reverse.getOrPut(allocator, value);

            if (res.found) {
                return .{ .entry = res.entry, .found = true };
            }

            return .{ .entry = res.entry, .found = false };
        }

        pub fn getOrPutReverseAssumeCapacity(
            self: *Self,
            value: V,
        ) struct { entry: *K, found: bool } {
            const res = self.reverse.getOrPutAssumeCapacity(value);

            if (res.found) return res;

            return .{ .entry = res.entry, .found = false };
        }

        // ============================================================
        // LOOKUP
        // ============================================================

        pub fn getValue(self: *Self, key: K) ?V {
            return self.forward.get(key);
        }

        pub fn getKey(self: *Self, value: V) ?K {
            return self.reverse.get(value);
        }

        pub fn containsKey(self: *Self, key: K) bool {
            return self.forward.contains(key);
        }

        pub fn containsValue(self: *Self, value: V) bool {
            return self.reverse.contains(value);
        }

        // ============================================================
        // REMOVAL
        // ============================================================

        pub fn removeByKey(self: *Self, key: K) void {
            if (self.forward.get(key)) |value| {
                _ = self.reverse.remove(value);
            }
            _ = self.forward.remove(key);
        }

        pub fn removeByValue(self: *Self, value: V) void {
            if (self.reverse.get(value)) |key| {
                _ = self.forward.remove(key);
            }
            _ = self.reverse.remove(value);
        }

        // ============================================================
        // ITERATION
        // ============================================================

        pub fn iterator(self: *Self) ForwardMap.Iterator {
            return self.forward.iterator();
        }

        pub fn reverseIterator(self: *Self) ReverseMap.Iterator {
            return self.reverse.iterator();
        }

        pub fn keyIterator(self: *Self) ForwardMap.KeyIterator {
            return self.forward.keyIterator();
        }

        pub fn valueIterator(self: *Self) ReverseMap.KeyIterator {
            return self.forward.keyIterator();
        }
    };
}
