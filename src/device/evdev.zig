const std = @import("std");
const model = @import("common").model;
const profile = @import("profile.zig");

pub const LinuxInputEvent = extern struct {
    time: LinuxTimeVal,
    type: u16,
    code: u16,
    value: i32,
};

pub const LinuxTimeVal = extern struct {
    sec: isize,
    usec: isize,
};

const EVIOCGRAB = 0x40044590;

// linux/input-event-codes.h (evdev)
const EV_KEY: u16 = 0x01;
const EV_REL: u16 = 0x02;
const REL_WHEEL: u16 = 0x08;

pub fn openEventDevice(event_path: []const u8) !std.posix.fd_t {
    return try std.posix.openat(std.os.linux.AT.FDCWD, event_path, .{ .ACCMODE = .RDWR }, 0);
}

pub fn grabDevice(fd: std.posix.fd_t) !void {
    var grab_on: c_int = 1;
    const rc = std.posix.system.ioctl(fd, EVIOCGRAB, @intFromPtr(&grab_on));
    if (rc != 0) {
        return error.IoctlGrabFailed;
    }
}

pub fn ungrabDevice(fd: std.posix.fd_t) void {
    var grab_off: c_int = 0;
    _ = std.posix.system.ioctl(fd, EVIOCGRAB, @intFromPtr(&grab_off));
}

pub fn waitForReadable(fd: std.posix.fd_t, timeout_ms: i32) !bool {
    var pollfds = [_]std.posix.pollfd{
        .{
            .fd = fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    const rc = try std.posix.poll(&pollfds, timeout_ms);
    if (rc == 0) return false;

    return (pollfds[0].revents & std.posix.POLL.IN) != 0;
}

pub fn readPhysicalEvent(fd: std.posix.fd_t) !?model.PhysicalInputEvent {
    while (true) {
        var buf: [@sizeOf(LinuxInputEvent)]u8 = undefined;
        const bytes_read = try std.posix.read(fd, &buf);
        if (bytes_read != buf.len) return error.ShortRead;

        const event: LinuxInputEvent = @bitCast(buf);

        if (event.type == EV_REL and event.code == REL_WHEEL) {
            if (event.value > 0) {
                return model.PhysicalInputEvent{
                    .control_id = "scroll_up",
                    .trigger = .press,
                };
            }
            if (event.value < 0) {
                return model.PhysicalInputEvent{
                    .control_id = "scroll_down",
                    .trigger = .press,
                };
            }
            return null;
        }

        if (event.type != EV_KEY) continue;

        if (profile.decodeEvdevKeyEvent(event.code, event.value)) |physical| {
            return physical;
        }
    }
}
