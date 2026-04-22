const std = @import("std");

pub const UserContext = struct {
    username: []u8,
    uid: u32,
    gid: u32,
    home: []u8,
};

pub fn detectExecutionUser(allocator: std.mem.Allocator) !?UserContext {
    if (std.posix.getenv("SUDO_USER")) |sudo_user| {
        return try lookupUserByName(allocator, sudo_user);
    }

    if (std.posix.getenv("USER")) |user| {
        return try lookupUserByName(allocator, user);
    }

    return null;
}

pub fn freeUserContext(allocator: std.mem.Allocator, ctx: UserContext) void {
    allocator.free(ctx.username);
    allocator.free(ctx.home);
}

fn lookupUserByName(allocator: std.mem.Allocator, username: []const u8) !?UserContext {
    const file = try std.fs.openFileAbsolute("/etc/passwd", .{ .mode = .read_only });
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.splitScalar(u8, line, ':');

        const name = fields.next() orelse continue;
        _ = fields.next() orelse continue; // password
        const uid_str = fields.next() orelse continue;
        const gid_str = fields.next() orelse continue;
        _ = fields.next() orelse continue; // gecos
        const home = fields.next() orelse continue;

        if (std.mem.eql(u8, name, username)) {
            return .{
                .username = try allocator.dupe(u8, name),
                .uid = try std.fmt.parseInt(u32, uid_str, 10),
                .gid = try std.fmt.parseInt(u32, gid_str, 10),
                .home = try allocator.dupe(u8, home),
            };
        }
    }

    return null;
}
