const std = @import("std");

pub const UserContext = struct {
    username: []u8,
    uid: u32,
    gid: u32,
    home: []u8,
};

pub fn detectExecutionUser(allocator: std.mem.Allocator) !?UserContext {
    if (getEnv("SUDO_USER")) |sudo_user| {
        return try lookupUserByName(allocator, sudo_user);
    }

    if (getEnv("USER")) |user| {
        return try lookupUserByName(allocator, user);
    }

    return null;
}

fn getEnv(comptime key: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(key) orelse return null;
    return std.mem.span(value);
}

pub fn freeUserContext(allocator: std.mem.Allocator, ctx: UserContext) void {
    allocator.free(ctx.username);
    allocator.free(ctx.home);
}

fn lookupUserByName(allocator: std.mem.Allocator, username: []const u8) !?UserContext {
    const contents = try readPasswdFile(allocator);
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

fn readPasswdFile(allocator: std.mem.Allocator) ![]u8 {
    const fd = try std.posix.openatZ(std.os.linux.AT.FDCWD, "/etc/passwd", .{ .CLOEXEC = true }, 0);
    defer _ = std.c.close(fd);

    const buffer = try allocator.alloc(u8, 1024 * 1024);
    errdefer allocator.free(buffer);

    var len: usize = 0;
    while (true) {
        if (len == buffer.len) return error.FileTooBig;

        const read_len = try std.posix.read(fd, buffer[len..]);
        if (read_len == 0) break;
        len += read_len;
    }

    const contents = try allocator.dupe(u8, buffer[0..len]);
    allocator.free(buffer);
    return contents;
}
