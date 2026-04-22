const std = @import("std");

pub const InputDeviceEntry = struct {
    path: []u8,
    name: []u8,
};

pub fn listEventDevicePaths(allocator: std.mem.Allocator) ![]InputDeviceEntry {
    var dir = try std.fs.openDirAbsolute("/dev/input", .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayListUnmanaged(InputDeviceEntry){};
    errdefer {
        for (entries.items) |entry| {
            allocator.free(entry.path);
            allocator.free(entry.name);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file and entry.kind != .character_device) continue;
        if (!std.mem.startsWith(u8, entry.name, "event")) continue;

        const full_path = try std.fmt.allocPrint(allocator, "/dev/input/{s}", .{entry.name});
        errdefer allocator.free(full_path);

        const device_name = readInputDeviceName(allocator, entry.name) catch |err| switch (err) {
            error.FileNotFound => try allocator.dupe(u8, "<unknown>"),
            else => return err,
        };
        errdefer allocator.free(device_name);

        try entries.append(allocator, .{
            .path = full_path,
            .name = device_name,
        });
    }

    std.mem.sort(InputDeviceEntry, entries.items, {}, lessThanPath);

    return try entries.toOwnedSlice(allocator);
}

pub fn freeDeviceEntries(allocator: std.mem.Allocator, items: []InputDeviceEntry) void {
    for (items) |item| {
        allocator.free(item.path);
        allocator.free(item.name);
    }
    allocator.free(items);
}

fn readInputDeviceName(allocator: std.mem.Allocator, event_name: []const u8) ![]u8 {
    const sysfs_path = try std.fmt.allocPrint(
        allocator,
        "/sys/class/input/{s}/device/name",
        .{event_name},
    );
    defer allocator.free(sysfs_path);

    const file = try std.fs.openFileAbsolute(sysfs_path, .{ .mode = .read_only });
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(contents);

    return try allocator.dupe(u8, std.mem.trim(u8, contents, " \t\r\n"));
}

fn lessThanPath(_: void, a: InputDeviceEntry, b: InputDeviceEntry) bool {
    return naturalLessThan(a.path, b.path);
}

fn naturalLessThan(a: []const u8, b: []const u8) bool {
    const a_num = trailingEventNumber(a) orelse return std.mem.lessThan(u8, a, b);
    const b_num = trailingEventNumber(b) orelse return std.mem.lessThan(u8, a, b);

    return a_num < b_num;
}

fn trailingEventNumber(path: []const u8) ?u32 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return null;
    const name = path[slash + 1 ..];
    if (!std.mem.startsWith(u8, name, "event")) return null;

    return std.fmt.parseInt(u32, name["event".len..], 10) catch null;
}
