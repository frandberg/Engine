const std = @import("std");
const objc = @import("objc");

const foundation = @import("foundation");
const Delegate = @import("Delegate");

const Input = foundation.Input;
const c = @import("c.zig");

//extern fn MTLCreateSystemDefaultDevice() objc.c.id;

const log = std.log.scoped(.CocoaContext);
const Atomic = std.atomic.Value;

const Context = @This();

const Object = objc.Object;
const nil: objc.c.id = @ptrFromInt(0);
extern const NSDefaultRunLoopMode: objc.c.id;

app: Object,
window: Object,
delegate: Delegate,
