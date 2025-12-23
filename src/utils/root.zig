pub const Mailbox = @import("Mailbox.zig");

pub fn bytesFromKB(kilobytes: usize) usize {
    return kilobytes * 1024;
}
pub fn bytesFromMB(megabytes: usize) usize {
    return megabytes * 1024 * 1024;
}

pub fn bytesFromGB(gigabytes: usize) usize {
    return gigabytes * 1024 * 1024 * 1024;
}
