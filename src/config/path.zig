const std = @import("std");
const AppNames = @import("common").types.AppNames;

pub fn getDefaultConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const home = try getPreferredHomeDir(allocator);
    defer allocator.free(home);

    return try std.fmt.allocPrint(
        allocator,
        "{s}/.config/{s}/{s}",
        .{ home, AppNames.daemon, AppNames.config_file_name },
    );
}

pub fn getDefaultConfigDirPath(allocator: std.mem.Allocator) ![]u8 {
    const home = try getPreferredHomeDir(allocator);
    defer allocator.free(home);

    return try std.fmt.allocPrint(
        allocator,
        "{s}/.config/{s}",
        .{ home, AppNames.daemon },
    );
}

fn getPreferredHomeDir(allocator: std.mem.Allocator) ![]u8 {
    if (getEnv("SUDO_USER")) |sudo_user| {
        if (try lookupHomeDirForUser(allocator, sudo_user)) |home| {
            return home;
        }
    }

    if (getEnv("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }

    return error.HomeNotSet;
}

fn getEnv(comptime key: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(key) orelse return null;
    return std.mem.span(value);
}

fn lookupHomeDirForUser(allocator: std.mem.Allocator, username: []const u8) !?[]u8 {
    const contents = try readPasswdFile(allocator);
    defer allocator.free(contents);

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var fields = std.mem.splitScalar(u8, line, ':');

        const name = fields.next() orelse continue;
        _ = fields.next() orelse continue; // password
        _ = fields.next() orelse continue; // uid
        _ = fields.next() orelse continue; // gid
        _ = fields.next() orelse continue; // gecos
        const home = fields.next() orelse continue;

        if (std.mem.eql(u8, name, username)) {
            return try allocator.dupe(u8, home);
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
