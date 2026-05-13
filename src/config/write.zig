const std = @import("std");

pub fn writeFileIfMissing(path: []const u8, contents: []const u8) !bool {
    const fd = std.posix.openat(std.os.linux.AT.FDCWD, path, .{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
        .CLOEXEC = true,
    }, 0o644) catch |err| switch (err) {
        error.PathAlreadyExists => return false,
        else => return err,
    };
    defer _ = std.c.close(fd);

    var written: usize = 0;
    while (written < contents.len) {
        const write_len = std.c.write(fd, contents[written..].ptr, contents.len - written);
        if (write_len < 0) return error.WriteFailed;
        if (write_len == 0) return error.WriteFailed;
        written += @intCast(write_len);
    }

    return true;
}
