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

pub fn openEventDevice(event_path: []const u8) !std.fs.File {
    return try std.fs.openFileAbsolute(event_path, .{
        .mode = .read_write,
    });
}

pub fn grabDevice(file: *std.fs.File) !void {
    var grab_on: c_int = 1;
    const rc = std.posix.system.ioctl(file.handle, EVIOCGRAB, @intFromPtr(&grab_on));
    if (rc != 0) {
        return error.IoctlGrabFailed;
    }
}

pub fn ungrabDevice(file: *std.fs.File) void {
    var grab_off: c_int = 0;
    _ = std.posix.system.ioctl(file.handle, EVIOCGRAB, @intFromPtr(&grab_off));
}

pub fn waitForReadable(file: *std.fs.File, timeout_ms: i32) !bool {
    var pollfds = [_]std.posix.pollfd{
        .{
            .fd = file.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    const rc = try std.posix.poll(&pollfds, timeout_ms);
    if (rc == 0) return false;

    return (pollfds[0].revents & std.posix.POLL.IN) != 0;
}

pub fn readPhysicalEvent(file: *std.fs.File) !?model.PhysicalInputEvent {
    while (true) {
        var buf: [@sizeOf(LinuxInputEvent)]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
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
