const std = @import("std");

pub fn configExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

pub fn readConfigFileAlloc(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();

    return try file.readToEndAlloc(allocator, 1024 * 1024);
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
