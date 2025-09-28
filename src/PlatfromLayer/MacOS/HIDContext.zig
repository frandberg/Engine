const std = @import("std");
const c = @cImport({
    @cInclude("IOKit/hid/IOHIDLib.h");
    @cInclude("IOkit/hid/IOHIDDevice.h");
    @cInclude("IOKit/hid/IOHIDElement.h");
    @cInclude("IOKit/IOKitLib.h");
});

const log = std.log.scoped(.HIDContext);

const HIDContext = @This();
const HIDManager = c.struct___IOHIDManager;

hid_manager: *HIDManager,
devices: []c.IOHIDDeviceRef,

pub const Input = struct {
    input_happened: bool,
};

pub fn init(allocator: std.mem.Allocator) !HIDContext {
    const hid_manager: *HIDManager = c.IOHIDManagerCreate(
        c.kCFAllocatorDefault,
        c.kIOHIDOptionsTypeNone,
    ) orelse return error.HIDManagerWasNull;
    const devices = try getAllDevices(allocator, hid_manager);

    return .{
        .hid_manager = hid_manager,
        .devices = devices,
    };
}

pub fn initCallback(self: *HIDContext) void {
    c.IOHIDManagerRegisterInputValueCallback(self.hid_manager, onInput, null);
}

pub fn deinit(_: *HIDContext) void {
    // Cleanup code if necessary
}

pub fn getAllDevices(allocator: std.mem.Allocator, hid_manager: *HIDManager) ![]c.IOHIDDeviceRef {
    c.IOHIDManagerSetDeviceMatching(hid_manager, null);
    const result = c.IOHIDManagerOpen(hid_manager, c.kIOHIDOptionsTypeSeizeDevice);
    if (result != 0) {
        return error.FailedToOpenHIDManager;
    }

    const devices_set = c.IOHIDManagerCopyDevices(hid_manager) orelse return error.FailedToCopyDevices;
    const device_count: usize = @intCast(c.CFSetGetCount(devices_set));
    const devices = try allocator.alloc(c.IOHIDDeviceRef, device_count);
    c.CFSetGetValues(devices_set, @ptrCast(devices.ptr));
    return devices;
}
fn onInput(
    _: ?*anyopaque,
    _: c.IOReturn,
    _: ?*anyopaque,
    value: c.IOHIDValueRef,
) callconv(.c) void {
    const element = c.IOHIDValueGetElement(value);
    const scan_code = c.IOHIDElementGetUsage(element);
    const pressed = c.IOHIDValueGetIntegerValue(value);

    if (pressed == 0) {
        log.info("key {} released\n", .{scan_code});
    } else {
        log.info("key {} pressed\n", .{scan_code});
    }
}
