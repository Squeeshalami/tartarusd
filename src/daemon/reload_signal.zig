const std = @import("std");

var reload_requested = std.atomic.Value(bool).init(false);

pub fn install() !void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSignal },
        .mask = std.mem.zeroes(std.posix.sigset_t),
        .flags = 0,
    };

    std.posix.sigaction(std.posix.SIG.HUP, &act, null);
}

pub fn consumeReloadRequest() bool {
    return reload_requested.swap(false, .acq_rel);
}

fn handleSignal(_: std.posix.SIG) callconv(.c) void {
    reload_requested.store(true, .release);
}
