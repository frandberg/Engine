pub const EntityID = u64;
pub const Signature = @import("Signature.zig");
pub const Component = @import("Component.zig");
pub const World = @import("World.zig");
pub const Iterator = @import("Iterator.zig");

const std = @import("std");
pub const log = std.log.scoped("ecs");

pub const PhysicsComponents = @import("Components/PhysicsComponents.zig");
pub const RendererComponents = @import("Components/RendererComponents.zig");

pub const RigidBody2D = PhysicsComponents.RigidBody2D;
pub const ColorSprite = RendererComponents.ColorSprite;
