const std = @import("std");

pub fn findDaemonPids(allocator: std.mem.Allocator) ![]u32 {
    var child = std.process.Child.init(
        &.{ "pgrep", "tartarusd" },
        allocator,
    );
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout_bytes = if (child.stdout) |stdout_file|
        try stdout_file.readToEndAlloc(allocator, 64 * 1024)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(stdout_bytes);

    const stderr_bytes = if (child.stderr) |stderr_file|
        try stderr_file.readToEndAlloc(allocator, 64 * 1024)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(stderr_bytes);

    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code == 1) {
                // pgrep returns 1 when no matching processes are found
                return try allocator.alloc(u32, 0);
            }
            if (code != 0) {
                std.debug.print("pgrep failed: {s}\n", .{stderr_bytes});
                return error.PgrepFailed;
            }
        },
        else => return error.PgrepFailed,
    }

    var pids = std.ArrayListUnmanaged(u32){};
    errdefer pids.deinit(allocator);

    var lines = std.mem.splitScalar(u8, stdout_bytes, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        const pid = try std.fmt.parseInt(u32, trimmed, 10);
        try pids.append(allocator, pid);
    }

    return try pids.toOwnedSlice(allocator);
}

pub fn reloadDaemonPids(pids: []const u32) !void {
    for (pids) |pid| {
        std.posix.kill(@intCast(pid), std.posix.SIG.HUP) catch |err| switch (err) {
            error.PermissionDenied => return error.PermissionDenied,
            error.ProcessNotFound => continue,
            else => return err,
        };
    }
}

pub fn quitDaemonPids(pids: []const u32) !void {
    for (pids) |pid| {
        std.posix.kill(@intCast(pid), std.posix.SIG.TERM) catch |err| switch (err) {
            error.PermissionDenied => return error.PermissionDenied,
            error.ProcessNotFound => continue,
            else => return err,
        };
    }
}
