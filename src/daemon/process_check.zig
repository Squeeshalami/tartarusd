const std = @import("std");

pub fn findDaemonPids(allocator: std.mem.Allocator, io: std.Io) ![]u32 {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "pgrep", "tartarusd" },
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| {
            if (code == 1) {
                return try allocator.alloc(u32, 0);
            }
            if (code != 0) {
                std.debug.print("pgrep failed: {s}\n", .{result.stderr});
                return error.PgrepFailed;
            }
        },
        else => return error.PgrepFailed,
    }

    var pids: std.ArrayListUnmanaged(u32) = .empty;
    errdefer pids.deinit(allocator);

    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;

        const pid = try std.fmt.parseInt(u32, trimmed, 10);
        try pids.append(allocator, pid);
    }

    return try pids.toOwnedSlice(allocator);
}
