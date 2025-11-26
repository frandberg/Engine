pub const EntityID = u64;
pub const Signature = @import("Signature.zig");
pub const Component = @import("Component.zig");
pub const World = @import("World.zig");
pub const System = @import("System.zig");

const std = @import("std");
pub const log = std.log.scoped("ecs");

const PhysicsComponents = @import("Components/PhysicComponents.zig");
const RendererComponents = @import("Components/RendererComponents.zig");

pub const RigidBody2D = PhysicsComponents.RigidBody2D;
pub const ColorSprite = RendererComponents.ColorSprite;
