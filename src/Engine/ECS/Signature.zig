const std = @import("std");

const Component = @import("Component.zig");
const Kind = Component.Kind;
const KindCount = Component.KindCount;

const componentIndex = Component.componentIndex;

pub const Signature = @This();

const BitsT = std.bit_set.StaticBitSet(KindCount);
bits: BitsT,

pub fn encode(components: []const Kind) Signature {
    var bit_set = BitsT.initEmpty();
    for (components) |component| {
        const index = componentIndex(component);
        bit_set.set(index);
    }
    return .{
        .bits = bit_set,
    };
}

pub fn encodeComponents(components: []const Component.Component) Signature {
    var tags: [KindCount]Kind = undefined;
    var count: usize = 0;

    for (components) |component| {
        switch (component) {
            inline else => |_, kind| {
                tags[count] = kind;
                count += 1;
            },
        }
    }
    return .encode(tags[0..count]);
}

pub fn decode(self: Signature) []const Kind {
    var components: [KindCount]Kind = undefined;
    var count: usize = 0;
    for (0..KindCount) |i| {
        if (self.bits.get(i)) {
            components[count] = @field(Kind, i);
            count += 1;
        }
    }
    return components[0..count];
}

pub fn addComponent(self: Signature, component: Kind) Signature {
    var new_bits = self.bits;
    const index = componentIndex(component);
    new_bits.set(index);
    return .{
        .bits = new_bits,
    };
}

pub fn removeComponent(self: Signature, component: Kind) Signature {
    var new_bits = self.bits;
    const index = componentIndex(component);
    new_bits.unset(index);
    return .{
        .bits = new_bits,
    };
}

pub fn hasComponent(self: Signature, component: Kind) bool {
    const index = componentIndex(component);
    return self.bits.isSet(index);
}
