const std = @import("std");
const model = @import("common").model;
const profile = @import("device").profile;

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

pub fn monitorDevice(event_path: []const u8) !void {
    const fd = try std.posix.openat(std.os.linux.AT.FDCWD, event_path, .{ .CLOEXEC = true }, 0);
    defer _ = std.c.close(fd);

    std.debug.print("monitoring device: {s}\n", .{event_path});
    std.debug.print("press Ctrl+C to stop\n", .{});

    while (true) {
        var buf: [@sizeOf(LinuxInputEvent)]u8 = undefined;
        const bytes_read = try std.posix.read(fd, &buf);
        if (bytes_read != buf.len) return error.ShortRead;

        const event: LinuxInputEvent = @bitCast(buf);

        std.debug.print(
            "sec={} usec={} {s} code={} value={} ({s})\n",
            .{
                event.time.sec,
                event.time.usec,
                eventTypeName(event.type),
                event.code,
                event.value,
                eventValueName(event.type, event.value),
            },
        );

        if (decodePhysicalEvent(event)) |physical| {
            std.debug.print(
                "  decoded -> control_id={s} trigger={s}",
                .{ physical.control_id, @tagName(physical.trigger) },
            );

            if (profile.mapControlToLogicalKey(physical.control_id)) |logical_key| {
                std.debug.print(" logical_key={s}", .{logical_key});
            }

            std.debug.print("\n", .{});
        }
    }
}

pub fn decodePhysicalEvent(event: LinuxInputEvent) ?model.PhysicalInputEvent {
    if (event.type != 1) return null;
    return profile.decodeEvdevKeyEvent(event.code, event.value);
}

fn eventTypeName(event_type: u16) []const u8 {
    return switch (event_type) {
        0 => "EV_SYN",
        1 => "EV_KEY",
        2 => "EV_REL",
        3 => "EV_ABS",
        4 => "EV_MSC",
        5 => "EV_SW",
        17 => "EV_LED",
        18 => "EV_SND",
        20 => "EV_REP",
        21 => "EV_FF",
        22 => "EV_PWR",
        23 => "EV_FF_STATUS",
        else => "EV_UNKNOWN",
    };
}

fn eventValueName(event_type: u16, value: i32) []const u8 {
    if (event_type == 1) {
        return switch (value) {
            0 => "release",
            1 => "press",
            2 => "repeat",
            else => "unknown",
        };
    }

    if (event_type == 0 and value == 0) {
        return "sync";
    }

    return "raw";
}
