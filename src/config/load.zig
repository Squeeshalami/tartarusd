const std = @import("std");

pub const LoadedConfigInfo = struct {
    default_layer: []const u8,
    layer_names: [][]const u8,
};

pub fn loadConfigInfoFromText(
    allocator: std.mem.Allocator,
    contents: []const u8,
) !LoadedConfigInfo {
    var default_layer: ?[]const u8 = null;
    var layer_names: std.ArrayListUnmanaged([]const u8) = .{};
    errdefer {
        for (layer_names.items) |name| allocator.free(name);
        layer_names.deinit(allocator);
    }

    var iter = std.mem.splitScalar(u8, contents, '\n');
    while (iter.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        if (std.mem.startsWith(u8, line, "default_layer")) {
            if (parseQuotedValue(line)) |value| {
                if (default_layer) |old| allocator.free(old);
                default_layer = try allocator.dupe(u8, value);
            }
            continue;
        }

        if (std.mem.startsWith(u8, line, "[layer.") and std.mem.endsWith(u8, line, "]")) {
            const start = "[layer.".len;
            const end = line.len - 1;
            if (end > start) {
                const name = line[start..end];
                try layer_names.append(allocator, try allocator.dupe(u8, name));
            }
        }
    }

    return .{
        .default_layer = default_layer orelse return error.MissingDefaultLayer,
        .layer_names = try layer_names.toOwnedSlice(allocator),
    };
}

fn parseQuotedValue(line: []const u8) ?[]const u8 {
    const eq_index = std.mem.indexOfScalar(u8, line, '=') orelse return null;
    const rhs = std.mem.trim(u8, line[eq_index + 1 ..], " \t");

    if (rhs.len < 2) return null;
    if (rhs[0] != '"' or rhs[rhs.len - 1] != '"') return null;

    return rhs[1 .. rhs.len - 1];
}
