const std = @import("std");
const model = @import("common").model;
const path = @import("path.zig");
const validate = @import("validate.zig");
const parse_bindings = @import("parse_bindings.zig");

pub fn loadParsedConfigDetailed(
    allocator: std.mem.Allocator,
    config_path: []const u8,
) !parse_bindings.ParseDetailedResult {
    const exists = validate.configExists(config_path);
    if (!exists) return error.ConfigMissing;

    const contents = try validate.readConfigFileAlloc(allocator, config_path);
    defer allocator.free(contents);

    return try parse_bindings.parseConfigModelFromTextDetailed(allocator, contents);
}

pub fn loadParsedConfig(
    allocator: std.mem.Allocator,
    config_path: []const u8,
) !model.ConfigModel {
    const detailed = try loadParsedConfigDetailed(allocator, config_path);
    return switch (detailed) {
        .success => |cfg| cfg,
        .parse_error => error.ConfigParseFailed,
    };
}

pub fn loadDefaultParsedConfigDetailed(
    allocator: std.mem.Allocator,
) !parse_bindings.ParseDetailedResult {
    const config_path = try path.getDefaultConfigPath(allocator);
    defer allocator.free(config_path);

    return try loadParsedConfigDetailed(allocator, config_path);
}

pub fn printParseError(info: parse_bindings.ParseErrorInfo) void {
    std.debug.print("  parse error: {s} ({s})\n", .{ @tagName(info.kind), info.error_name });
    if (info.line_number > 0) {
        std.debug.print("  line {}: {s}\n", .{ info.line_number, info.line_contents });
    }
}

pub fn loadDefaultParsedConfig(allocator: std.mem.Allocator) !model.ConfigModel {
    const config_path = try path.getDefaultConfigPath(allocator);
    defer allocator.free(config_path);

    return try loadParsedConfig(allocator, config_path);
}
