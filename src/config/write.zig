const std = @import("std");

pub fn writeFileIfMissing(path: []const u8, contents: []const u8) !bool {
    const file = std.fs.createFileAbsolute(path, .{
        .read = true,
        .truncate = false,
        .exclusive = true,
    }) catch |err| switch (err) {
        error.PathAlreadyExists => return false,
        else => return err,
    };
    defer file.close();

    try file.writeAll(contents);
    return true;
}
