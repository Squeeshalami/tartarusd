const std = @import("std");

var verbose_enabled: bool = false;

pub fn setVerbose(enabled: bool) void {
    verbose_enabled = enabled;
}

pub fn isVerbose() bool {
    return verbose_enabled;
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

pub fn verbose(comptime fmt: []const u8, args: anytype) void {
    if (!verbose_enabled) return;
    std.debug.print(fmt, args);
}
