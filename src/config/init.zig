const std = @import("std");
const path = @import("path.zig");

pub fn ensureDefaultConfigDir(allocator: std.mem.Allocator) ![]u8 {
    const dir_path = try path.getDefaultConfigDirPath(allocator);
    errdefer allocator.free(dir_path);

    std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    return dir_path;
}
