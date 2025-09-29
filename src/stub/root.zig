const engine = @import("engine");
pub export fn initGameMemory(_: engine.GameMemory) void {}
pub export fn updateAndRender(_: *engine.RenderCommandBuffer, _: *const engine.GameMemory, _: f64) void {}
