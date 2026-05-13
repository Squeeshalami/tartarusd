const std = @import("std");

pub fn configExists(path: []const u8) bool {
    const fd = std.posix.openat(std.os.linux.AT.FDCWD, path, .{ .CLOEXEC = true }, 0) catch return false;
    defer _ = std.c.close(fd);
    return true;
}

pub fn readConfigFileAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const fd = try std.posix.openat(std.os.linux.AT.FDCWD, path, .{ .CLOEXEC = true }, 0);
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

pub fn validateConfigText(contents: []const u8) !void {
    if (!containsLine(contents, "[device]")) {
        return error.MissingDeviceSection;
    }

    if (!containsLine(contents, "[global]")) {
        return error.MissingGlobalSection;
    }

    if (!containsSubstring(contents, "[layer.")) {
        return error.MissingLayerSection;
    }

    if (!containsSubstring(contents, "default_layer")) {
        return error.MissingDefaultLayer;
    }
}

fn containsLine(contents: []const u8, needle: []const u8) bool {
    var iter = std.mem.splitScalar(u8, contents, '\n');
    while (iter.next()) |line| {
        if (std.mem.eql(u8, std.mem.trim(u8, line, " \t\r"), needle)) {
            return true;
        }
    }
    return false;
}

fn containsSubstring(contents: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, contents, needle) != null;
}
