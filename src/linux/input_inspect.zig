const std = @import("std");

pub const DeviceInfo = struct {
    event_path: []u8,
    event_name: []u8,
    device_name: []u8,
    sysfs_device_path: []u8,
    vendor_id: ?[]u8,
    product_id: ?[]u8,
};

pub fn inspectEventDevice(
    allocator: std.mem.Allocator,
    event_path: []const u8,
) !DeviceInfo {
    const event_name = try extractEventName(allocator, event_path);
    errdefer allocator.free(event_name);

    const sysfs_event_dir = try std.fmt.allocPrint(
        allocator,
        "/sys/class/input/{s}",
        .{event_name},
    );
    defer allocator.free(sysfs_event_dir);

    const sysfs_device_path = try readDeviceSymlinkTarget(allocator, sysfs_event_dir);
    errdefer allocator.free(sysfs_device_path);

    const device_name = readDeviceNameFromEventName(allocator, event_name) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, "<unknown>"),
        else => return err,
    };
    errdefer allocator.free(device_name);

    const vendor_id = readMaybeTrimmedFile(
        allocator,
        sysfs_device_path,
        "id/vendor",
    ) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    errdefer if (vendor_id) |v| allocator.free(v);

    const product_id = readMaybeTrimmedFile(
        allocator,
        sysfs_device_path,
        "id/product",
    ) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    errdefer if (product_id) |p| allocator.free(p);

    return .{
        .event_path = try allocator.dupe(u8, event_path),
        .event_name = event_name,
        .device_name = device_name,
        .sysfs_device_path = sysfs_device_path,
        .vendor_id = vendor_id,
        .product_id = product_id,
    };
}

pub fn freeDeviceInfo(allocator: std.mem.Allocator, info: DeviceInfo) void {
    allocator.free(info.event_path);
    allocator.free(info.event_name);
    allocator.free(info.device_name);
    allocator.free(info.sysfs_device_path);
    if (info.vendor_id) |v| allocator.free(v);
    if (info.product_id) |p| allocator.free(p);
}

pub fn findTartarusEventPath(allocator: std.mem.Allocator) !?[]u8 {
    const paths = try findTartarusEventPaths(allocator);
    defer {
        for (paths) |path| allocator.free(path);
        allocator.free(paths);
    }

    if (paths.len == 0) return null;
    return try allocator.dupe(u8, paths[0]);
}

pub fn findTartarusEventPaths(allocator: std.mem.Allocator) ![][]u8 {
    const devices = try @import("input_list.zig").listEventDevicePaths(allocator);
    defer @import("input_list.zig").freeDeviceEntries(allocator, devices);

    var matches = std.ArrayListUnmanaged([]u8){};
    errdefer {
        for (matches.items) |path| allocator.free(path);
        matches.deinit(allocator);
    }

    for (devices) |device| {
        const info = inspectEventDevice(allocator, device.path) catch continue;
        defer freeDeviceInfo(allocator, info);

        const name_ok =
            std.mem.indexOf(u8, info.device_name, "Razer Tartarus V2") != null or
            std.mem.indexOf(u8, info.device_name, "Razer Tartarus") != null;

        if (name_ok) {
            try matches.append(allocator, try allocator.dupe(u8, device.path));
        }
    }

    return try matches.toOwnedSlice(allocator);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (asciiEqlIgnoreCase(haystack[i .. i + needle.len], needle)) {
            return true;
        }
    }
    return false;
}

fn asciiEqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

fn extractEventName(allocator: std.mem.Allocator, event_path: []const u8) ![]u8 {
    const slash = std.mem.lastIndexOfScalar(u8, event_path, '/') orelse return error.InvalidEventPath;
    const event_name = event_path[slash + 1 ..];

    if (!std.mem.startsWith(u8, event_name, "event")) {
        return error.InvalidEventPath;
    }

    return try allocator.dupe(u8, event_name);
}

fn readDeviceNameFromEventName(allocator: std.mem.Allocator, event_name: []const u8) ![]u8 {
    const sysfs_name_path = try std.fmt.allocPrint(
        allocator,
        "/sys/class/input/{s}/device/name",
        .{event_name},
    );
    defer allocator.free(sysfs_name_path);

    return try readTrimmedFileAbsolute(allocator, sysfs_name_path);
}

fn readDeviceSymlinkTarget(allocator: std.mem.Allocator, sysfs_event_dir: []const u8) ![]u8 {
    const device_link = try std.fmt.allocPrint(
        allocator,
        "{s}/device",
        .{sysfs_event_dir},
    );
    defer allocator.free(device_link);

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const target = try std.posix.readlink(device_link, &buf);

    return try std.fs.path.resolve(allocator, &.{ sysfs_event_dir, target });
}

fn readMaybeTrimmedFile(
    allocator: std.mem.Allocator,
    base_dir: []const u8,
    relative_path: []const u8,
) ![]u8 {
    const full_path = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ base_dir, relative_path },
    );
    defer allocator.free(full_path);

    return try readTrimmedFileAbsolute(allocator, full_path);
}

fn readTrimmedFileAbsolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.openFileAbsolute(path, .{ .mode = .read_only });
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 4096);
    defer allocator.free(contents);

    return try allocator.dupe(u8, std.mem.trim(u8, contents, " \t\r\n"));
}
