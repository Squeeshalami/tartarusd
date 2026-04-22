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
    if (std.posix.getenv("SUDO_USER")) |sudo_user| {
        if (try lookupHomeDirForUser(allocator, sudo_user)) |home| {
            return home;
        }
    }

    if (std.posix.getenv("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }

    return error.HomeNotSet;
}

fn lookupHomeDirForUser(allocator: std.mem.Allocator, username: []const u8) !?[]u8 {
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
