const std = @import("std");
const model = @import("common").model;

pub const ParseErrorInfo = struct {
    line_number: usize,
    line_contents: []const u8,
    kind: Kind,
    error_name: []const u8,

    pub const Kind = enum {
        InvalidBindingLine,
        MissingSectionHeader,
        InvalidArrayItem,
        MissingEquals,
        UnknownActionType,
        MissingRequiredField,
        InvalidTrigger,
        InvalidLayerMode,
        Other,
    };
};

pub const ParseDetailedResult = union(enum) {
    success: model.ConfigModel,
    parse_error: ParseErrorInfo,
};

pub fn parseConfigModelFromText(
    allocator: std.mem.Allocator,
    contents: []const u8,
) !model.ConfigModel {
    const detailed = try parseConfigModelFromTextDetailed(allocator, contents);
    return switch (detailed) {
        .success => |cfg| cfg,
        .parse_error => |info| {
            allocator.free(info.line_contents);
            return error.ConfigParseFailed;
        },
    };
}

pub fn parseConfigModelFromTextDetailed(
    allocator: std.mem.Allocator,
    contents: []const u8,
) !ParseDetailedResult {
    var default_layer: ?[]u8 = null;

    var layers: std.ArrayListUnmanaged(model.Layer) = .empty;
    var should_cleanup = true;
    defer {
        if (should_cleanup) {
            for (layers.items) |layer| {
                allocator.free(layer.name);
                freeBindings(allocator, layer.bindings);
            }
            layers.deinit(allocator);

            if (default_layer) |name| allocator.free(name);
        }
    }

    var current_layer_name: ?[]u8 = null;
    var current_bindings: std.ArrayListUnmanaged(model.Binding) = .empty;

    defer {
        if (current_layer_name) |name| allocator.free(name);
        freeBindings(allocator, current_bindings.items);
        current_bindings.deinit(allocator);
    }

    var iter = std.mem.splitScalar(u8, contents, '\n');
    var line_number: usize = 0;
    while (iter.next()) |raw_line| {
        line_number += 1;
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        if (std.mem.startsWith(u8, line, "default_layer")) {
            const value = parseQuotedAssignment(line) orelse {
                const parse_err: anyerror = if (std.mem.indexOfScalar(u8, line, '=') == null)
                    error.MissingEquals
                else
                    error.MissingRequiredField;
                return try makeParseFailure(
                    allocator,
                    line_number,
                    raw_line,
                    mapParseKind(parse_err),
                    parse_err,
                );
            };

            if (default_layer) |old| allocator.free(old);
            default_layer = try allocator.dupe(u8, value);
            continue;
        }

        if (std.mem.indexOfScalar(u8, line, '=') != null and current_layer_name == null) {
            return try makeParseFailure(
                allocator,
                line_number,
                raw_line,
                .MissingSectionHeader,
                error.MissingSectionHeader,
            );
        }

        if (isLayerHeader(line)) {
            if (current_layer_name != null) {
                try flushCurrentLayer(
                    allocator,
                    &layers,
                    &current_layer_name,
                    &current_bindings,
                );
            }

            const layer_name = extractLayerName(line) orelse {
                return try makeParseFailure(
                    allocator,
                    line_number,
                    raw_line,
                    .InvalidBindingLine,
                    error.InvalidBindingLine,
                );
            };
            current_layer_name = try allocator.dupe(u8, layer_name);
            continue;
        }

        if (line[0] == '[') {
            if (current_layer_name != null) {
                try flushCurrentLayer(
                    allocator,
                    &layers,
                    &current_layer_name,
                    &current_bindings,
                );
            }
            continue;
        }

        if (current_layer_name != null) {
            const binding = parseBindingLineDetailed(allocator, line) catch |err| {
                switch (err) {
                    error.OutOfMemory => return err,
                    else => {
                        return try makeParseFailure(
                            allocator,
                            line_number,
                            raw_line,
                            mapParseKind(err),
                            err,
                        );
                    },
                }
            };
            try current_bindings.append(allocator, binding);
            continue;
        }

        return try makeParseFailure(
            allocator,
            line_number,
            raw_line,
            .Other,
            error.InvalidBindingLine,
        );
    }

    if (current_layer_name != null) {
        try flushCurrentLayer(
            allocator,
            &layers,
            &current_layer_name,
            &current_bindings,
        );
    }

    const resolved_default_layer = default_layer orelse {
        return try makeParseFailure(
            allocator,
            0,
            "",
            .MissingRequiredField,
            error.MissingDefaultLayer,
        );
    };

    const owned_layers = try layers.toOwnedSlice(allocator);
    default_layer = null;
    should_cleanup = false;

    return .{
        .success = .{
            .default_layer = resolved_default_layer,
            .layers = owned_layers,
        },
    };
}

fn flushCurrentLayer(
    allocator: std.mem.Allocator,
    layers: *std.ArrayListUnmanaged(model.Layer),
    current_layer_name: *?[]u8,
    current_bindings: *std.ArrayListUnmanaged(model.Binding),
) !void {
    const name = current_layer_name.* orelse return;

    const owned_bindings = try current_bindings.toOwnedSlice(allocator);

    try layers.append(allocator, .{
        .name = name,
        .bindings = owned_bindings,
    });

    current_layer_name.* = null;
    current_bindings.* = .empty;
}

fn isLayerHeader(line: []const u8) bool {
    return std.mem.startsWith(u8, line, "[layer.") and std.mem.endsWith(u8, line, "]");
}

fn extractLayerName(line: []const u8) ?[]const u8 {
    const start = "[layer.".len;
    const end = line.len - 1;
    if (end <= start) return null;
    return line[start..end];
}

fn parseQuotedAssignment(line: []const u8) ?[]const u8 {
    const eq_index = std.mem.indexOfScalar(u8, line, '=') orelse return null;
    const rhs = std.mem.trim(u8, line[eq_index + 1 ..], " \t");
    if (rhs.len < 2) return null;
    if (rhs[0] != '"' or rhs[rhs.len - 1] != '"') return null;
    return rhs[1 .. rhs.len - 1];
}

fn makeParseFailure(
    allocator: std.mem.Allocator,
    line_number: usize,
    line_contents: []const u8,
    kind: ParseErrorInfo.Kind,
    err: anyerror,
) !ParseDetailedResult {
    return .{
        .parse_error = .{
            .line_number = line_number,
            .line_contents = try allocator.dupe(u8, line_contents),
            .kind = kind,
            .error_name = @errorName(err),
        },
    };
}

fn mapParseKind(err: anyerror) ParseErrorInfo.Kind {
    return switch (err) {
        error.InvalidBindingLine => .InvalidBindingLine,
        error.MissingSectionHeader => .MissingSectionHeader,
        error.InvalidArrayItem, error.InvalidArray => .InvalidArrayItem,
        error.MissingEquals => .MissingEquals,
        error.UnknownActionType => .UnknownActionType,
        error.MissingRequiredField, error.MissingDefaultLayer => .MissingRequiredField,
        error.InvalidTrigger => .InvalidTrigger,
        error.InvalidLayerMode => .InvalidLayerMode,
        else => .Other,
    };
}

const ParseBindingError = error{
    InvalidBindingLine,
    MissingEquals,
    UnknownActionType,
    MissingRequiredField,
    InvalidLayerMode,
    InvalidArrayItem,
};

fn parseBindingLineDetailed(
    allocator: std.mem.Allocator,
    line: []const u8,
) (ParseBindingError || std.mem.Allocator.Error)!model.Binding {
    const eq_index = std.mem.indexOfScalar(u8, line, '=') orelse return error.MissingEquals;

    const logical_key = std.mem.trim(u8, line[0..eq_index], " \t");
    const rhs = std.mem.trim(u8, line[eq_index + 1 ..], " \t");

    if (logical_key.len == 0) return error.InvalidBindingLine;
    if (rhs.len < 2 or rhs[0] != '{' or rhs[rhs.len - 1] != '}') {
        return error.InvalidBindingLine;
    }

    const body = rhs[1 .. rhs.len - 1];
    const action_type = extractFieldValue(body, "type") orelse return error.MissingRequiredField;

    if (std.mem.eql(u8, action_type, "key")) {
        const key_name = extractFieldValue(body, "key") orelse return error.MissingRequiredField;

        return .{
            .logical_key = try allocator.dupe(u8, logical_key),
            .action = .{ .key = .{
                .key = try allocator.dupe(u8, key_name),
                .trigger = .press,
            } },
        };
    }

    if (std.mem.eql(u8, action_type, "layer")) {
        const target = extractFieldValue(body, "target") orelse return error.MissingRequiredField;
        const mode_str = extractFieldValue(body, "mode") orelse return error.MissingRequiredField;
        const mode = parseLayerMode(mode_str) orelse return error.InvalidLayerMode;

        return .{
            .logical_key = try allocator.dupe(u8, logical_key),
            .action = .{ .layer = .{
                .target = try allocator.dupe(u8, target),
                .mode = mode,
            } },
        };
    }

    if (std.mem.eql(u8, action_type, "combo")) {
        const keys_value = extractArrayField(body, "keys") orelse return error.MissingRequiredField;
        const parsed_keys = parseStringArray(allocator, keys_value) catch |err| switch (err) {
            error.InvalidArray, error.InvalidArrayItem => return error.InvalidArrayItem,
            error.OutOfMemory => return error.OutOfMemory,
        };
        errdefer freeStringSlice(allocator, parsed_keys);

        return .{
            .logical_key = try allocator.dupe(u8, logical_key),
            .action = .{ .combo = .{
                .keys = parsed_keys,
                .trigger = .press,
            } },
        };
    }

    if (std.mem.eql(u8, action_type, "exec")) {
        const program = extractFieldValue(body, "program") orelse return error.MissingRequiredField;
        const args_value = extractArrayField(body, "args") orelse "[]";
        const parsed_args = parseStringArray(allocator, args_value) catch |err| switch (err) {
            error.InvalidArray, error.InvalidArrayItem => return error.InvalidArrayItem,
            error.OutOfMemory => return error.OutOfMemory,
        };
        errdefer freeStringSlice(allocator, parsed_args);

        return .{
            .logical_key = try allocator.dupe(u8, logical_key),
            .action = .{ .exec = .{
                .program = try allocator.dupe(u8, program),
                .args = parsed_args,
            } },
        };
    }

    if (std.mem.eql(u8, action_type, "command")) {
        const shell = extractFieldValue(body, "shell") orelse return error.MissingRequiredField;
        const detach = extractBoolField(body, "detach") orelse true;

        return .{
            .logical_key = try allocator.dupe(u8, logical_key),
            .action = .{ .command = .{
                .shell = try allocator.dupe(u8, shell),
                .detach = detach,
                .cooldown_ms = 0,
            } },
        };
    }

    return error.UnknownActionType;
}

fn extractFieldValue(body: []const u8, field_name: []const u8) ?[]const u8 {
    var parts = splitTopLevelComma(body);
    while (parts.next()) |raw_part| {
        const part = std.mem.trim(u8, raw_part, " \t");
        const eq_index = std.mem.indexOfScalar(u8, part, '=') orelse continue;

        const key = std.mem.trim(u8, part[0..eq_index], " \t");
        const value = std.mem.trim(u8, part[eq_index + 1 ..], " \t");

        if (!std.mem.eql(u8, key, field_name)) continue;
        if (value.len < 2) return null;
        if (value[0] != '"' or value[value.len - 1] != '"') return null;

        return value[1 .. value.len - 1];
    }
    return null;
}

fn extractArrayField(body: []const u8, field_name: []const u8) ?[]const u8 {
    var parts = splitTopLevelComma(body);
    while (parts.next()) |raw_part| {
        const part = std.mem.trim(u8, raw_part, " \t");
        const eq_index = std.mem.indexOfScalar(u8, part, '=') orelse continue;

        const key = std.mem.trim(u8, part[0..eq_index], " \t");
        const value = std.mem.trim(u8, part[eq_index + 1 ..], " \t");

        if (!std.mem.eql(u8, key, field_name)) continue;
        if (value.len < 2) return null;
        if (value[0] != '[' or value[value.len - 1] != ']') return null;

        return value;
    }
    return null;
}

fn extractBoolField(body: []const u8, field_name: []const u8) ?bool {
    var parts = splitTopLevelComma(body);
    while (parts.next()) |raw_part| {
        const part = std.mem.trim(u8, raw_part, " \t");
        const eq_index = std.mem.indexOfScalar(u8, part, '=') orelse continue;

        const key = std.mem.trim(u8, part[0..eq_index], " \t");
        const value = std.mem.trim(u8, part[eq_index + 1 ..], " \t");

        if (!std.mem.eql(u8, key, field_name)) continue;
        if (std.mem.eql(u8, value, "true")) return true;
        if (std.mem.eql(u8, value, "false")) return false;
        return null;
    }
    return null;
}

fn parseLayerMode(value: []const u8) ?model.LayerMode {
    if (std.mem.eql(u8, value, "set")) return .set;
    if (std.mem.eql(u8, value, "hold")) return .hold;
    if (std.mem.eql(u8, value, "toggle")) return .toggle;
    return null;
}

fn parseStringArray(
    allocator: std.mem.Allocator,
    value: []const u8,
) ![][]const u8 {
    if (value.len < 2 or value[0] != '[' or value[value.len - 1] != ']') {
        return error.InvalidArray;
    }

    const inner = std.mem.trim(u8, value[1 .. value.len - 1], " \t");
    if (inner.len == 0) return try allocator.alloc([]const u8, 0);

    var items: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        freeStringSlice(allocator, items.items);
        items.deinit(allocator);
    }

    var parts = splitTopLevelComma(inner);
    while (parts.next()) |raw_part| {
        const part = std.mem.trim(u8, raw_part, " \t");
        if (part.len < 2) return error.InvalidArrayItem;
        if (part[0] != '"' or part[part.len - 1] != '"') return error.InvalidArrayItem;

        try items.append(allocator, try allocator.dupe(u8, part[1 .. part.len - 1]));
    }

    return try items.toOwnedSlice(allocator);
}

fn freeStringSlice(allocator: std.mem.Allocator, items: []const []const u8) void {
    for (items) |item| allocator.free(item);
    allocator.free(items);
}

fn freeBindings(allocator: std.mem.Allocator, bindings: []const model.Binding) void {
    for (bindings) |binding| {
        allocator.free(binding.logical_key);

        switch (binding.action) {
            .key => |a| allocator.free(a.key),
            .layer => |a| allocator.free(a.target),
            .combo => |a| freeStringSlice(allocator, a.keys),
            .exec => |a| {
                allocator.free(a.program);
                freeStringSlice(allocator, a.args);
            },
            .command => |a| allocator.free(a.shell),
        }
    }
}

fn splitTopLevelComma(input: []const u8) TopLevelCommaSplitIterator {
    return .{
        .input = input,
        .index = 0,
    };
}

const TopLevelCommaSplitIterator = struct {
    input: []const u8,
    index: usize,

    fn next(self: *TopLevelCommaSplitIterator) ?[]const u8 {
        if (self.index >= self.input.len) return null;

        const start = self.index;
        var bracket_depth: usize = 0;
        var in_string = false;
        var i = self.index;

        while (i < self.input.len) : (i += 1) {
            const c = self.input[i];

            if (c == '"') {
                in_string = !in_string;
                continue;
            }

            if (in_string) continue;

            switch (c) {
                '[' => {
                    bracket_depth += 1;
                },
                ']' => {
                    if (bracket_depth > 0) {
                        bracket_depth -= 1;
                    }
                },
                ',' => {
                    if (bracket_depth == 0) {
                        self.index = i + 1;
                        return self.input[start..i];
                    }
                },
                else => {},
            }
        }

        self.index = self.input.len;
        return self.input[start..];
    }
};
