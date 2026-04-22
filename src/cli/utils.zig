const std = @import("std");
const config = @import("config");

pub fn loadParsedConfig(
    allocator: std.mem.Allocator,
    path: []const u8,
) !@import("common").model.ConfigModel {
    return try config.runtime.loadParsedConfig(allocator, path);
}
