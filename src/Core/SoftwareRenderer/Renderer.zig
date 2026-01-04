const std = @import("std");
const utils = @import("utils");

const core = @import("../root.zig");
const Game = @import("../Game.zig");

const math = @import("math");
const Mat3f = math.Mat3f;

pub const FramebufferPool = @import("FramebufferPool.zig");
pub const Texture = @import("Texture.zig");
const Target = @import("Target.zig").Target;

pub const CommandBuffer = @import("CommandBuffer.zig");
const CommandBufferPool = @import("CommandBufferPool.zig");
const Command = CommandBuffer.Command;

const Graphics = @import("../Graphics/Graphics.zig");
const Camera = Graphics.Camera;
//const WindowSpec = core.WindowSpec;

const assert = std.debug.assert;
const Atomic = std.atomic.Value;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayHashMap = std.AutoArrayHashMapUnmanaged;
const Semaphore = std.Thread.Semaphore;

const CmdExecutor = @import("CommandExecutor.zig");
const drawColorSprite = CmdExecutor.drawColorSprite;
const toBGRA = CmdExecutor.toBGRA;

const Renderer = @This();
const log = std.log.scoped(.renderer);

const max_frames_in_flight = CommandBufferPool.max_frames_in_flight;

gpa: Allocator,
arena_state: ArenaAllocator,
cmd_buffer_pool: CommandBufferPool,
render_targets: ArrayHashMap(Graphics.Target.Handle, Target),
wake_up: Semaphore = .{},

state: State = .{},
next_target_id: Graphics.Target.Handle = 0,

pub fn init(gpa: Allocator) !Renderer {
    const arena_state = ArenaAllocator.init(gpa);
    const cmd_buffer_pool: CommandBufferPool = try .init(gpa);

    return .{
        .gpa = gpa,
        .arena_state = arena_state,
        .cmd_buffer_pool = cmd_buffer_pool,
        .render_targets = .empty,
    };
}

pub fn deinit(self: *Renderer) void {
    for (self.render_targets.values()) |*target| {
        target.deinit(self.gpa);
    }
    self.render_targets.deinit(self.gpa);
    self.cmd_buffer_pool.deinit(self.gpa);
    self.arena_state.deinit();
}

pub fn renderLoop(self: *Renderer, isRunning: *const fn () bool) void {
    while (isRunning()) {
        while (self.cmd_buffer_pool.consume()) |cmd_buffer| {
            for (cmd_buffer.slice()) |command| {
                self.executeCommand(command) catch @panic("failed to execute command");
            }
            self.cmd_buffer_pool.release(cmd_buffer);
            self.resetState();
        }
        self.wake_up.wait();
    }
    log.info("Render loop exited", .{});
}

pub fn createWindowRenderTarget(self: *Renderer, spec: Graphics.Target.Spec) !Graphics.Target.Handle {
    const framebuffer_pool: FramebufferPool = try .init(self.gpa, spec.width, spec.height, spec.format);
    const target_id = self.next_target_id;
    try self.render_targets.put(self.gpa, target_id, .{ .window = framebuffer_pool });
    self.next_target_id += 1;
    return target_id;
}

pub fn acquireCommandBuffer(self: *Renderer) CommandBuffer {
    return self.cmd_buffer_pool.acquire();
}

pub fn submitCommandBuffer(self: *Renderer, command_buffer: CommandBuffer) void {
    self.cmd_buffer_pool.publish(command_buffer);
    self.wake_up.post();
}

fn acquireTarget(self: *Renderer, target_id: Graphics.Target.Handle) !Texture {
    const gop = try self.state.acquired_tagets.getOrPut(self.arena_state.allocator(), target_id);
    if (gop.found_existing) {
        return gop.value_ptr.*;
    }
    const target = self.render_targets.getPtr(target_id) orelse return error.UnknownRenderTarget;
    const bound_target = target.acquire() orelse return error.FailedToAcquireRenderTarget;

    gop.value_ptr.* = bound_target;
    return bound_target;
}

fn resetState(self: *Renderer) void {
    for (self.state.acquired_tagets.keys(), self.state.acquired_tagets.values()) |target_handle, texture| {
        self.render_targets.getPtr(target_handle).?.release(texture);
    }
    _ = self.arena_state.reset(.retain_capacity);
    self.state = .{};
}

pub fn executeCommand(self: *Renderer, command: Graphics.Command) !void {
    switch (command) {
        .set_view => |view_spec| {
            try self.setView(view_spec);
        },
        .draw => |draw_cmd| {
            self.draw(draw_cmd);
        },
        .clear => |clear_cmd| {
            try self.clear(clear_cmd);
        },
    }
}

fn setView(self: *Renderer, view_spec: Graphics.ViewSpec) !void {
    const target = try self.acquireTarget(view_spec.target);
    const aspect_ratio: f32 = @as(f32, @floatFromInt(target.width)) / @as(f32, @floatFromInt(target.height));
    self.state.view = .{
        //TEMPORARY
        .view_projection = view_spec.camera.viewProjection(-aspect_ratio, aspect_ratio, -1.0, 1.0),
        .viewport = view_spec.viewport,
    };

    self.state.target = target;
}

fn draw(self: *const Renderer, draw_cmd: Graphics.Command.Draw) void {
    if (self.state.target) |target| {
        if (self.state.view) |view| {
            switch (draw_cmd) {
                .color_sprite => |draw_color_sprite| {
                    drawColorSprite(
                        target,
                        view,
                        draw_color_sprite.sprite,
                        draw_color_sprite.transform,
                    );
                },
            }
        } else {
            log.warn("No view set, ignoring draw command", .{});
        }
    } else {
        log.warn("No render target set, ignoring draw command", .{});
    }
}

fn clear(self: *Renderer, clear_cmd: Graphics.Command.Clear) !void {
    const texture = try self.acquireTarget(clear_cmd.target);

    switch (texture.memory) {
        inline else => |memory, format| {
            const pixel_color = format.pixel(clear_cmd.color);

            @memset(memory, pixel_color);
        },
    }
}

pub const View = struct {
    view_projection: math.Mat3f,
    viewport: math.Rect,
};

const State = struct {
    view: ?View = null,
    target: ?Texture = null,
    acquired_tagets: ArrayHashMap(Graphics.Target.Handle, Texture) = .empty,
};
