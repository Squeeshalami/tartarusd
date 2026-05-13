const std = @import("std");
const path = @import("path.zig");

pub fn ensureDefaultConfigDir(allocator: std.mem.Allocator) ![]u8 {
    const dir_path = try path.getDefaultConfigDirPath(allocator);
    errdefer allocator.free(dir_path);

    const dir_path_z = try allocator.dupeZ(u8, dir_path);
    defer allocator.free(dir_path_z);

    if (std.c.mkdir(dir_path_z, 0o755) != 0) {
        const fd = std.posix.openat(std.os.linux.AT.FDCWD, dir_path, .{ .DIRECTORY = true }, 0) catch {
            return error.MakeDirFailed;
        };
        _ = std.c.close(fd);
    }

    return dir_path;
}
