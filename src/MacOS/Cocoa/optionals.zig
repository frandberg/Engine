const objc = @import("objc");
pub fn wrap(comptime T: type, object: objc.Object) ?T {
    if (object.value == @as(objc.c.id, @ptrFromInt(0))) return null;
    return .{ .object = object };
}

pub fn unwrap(comptime T: type, instance: ?T) objc.c.id {
    if (instance) |inst| return inst.object.value;
    return @as(objc.c.id, @ptrFromInt(0));
}
