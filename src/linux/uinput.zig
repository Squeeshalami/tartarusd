const std = @import("std");

const c = @cImport({
    @cInclude("linux/uinput.h");
    @cInclude("linux/input.h");
    @cInclude("fcntl.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h");
    @cInclude("string.h");
});

pub const VirtualKeyboard = struct {
    fd: std.posix.fd_t,

    pub fn create() !VirtualKeyboard {
        const fd = std.posix.open("/dev/uinput", .{ .ACCMODE = .RDWR }, 0) catch |err| switch (err) {
            error.FileNotFound => return error.UinputUnavailable,
            else => return err,
        };
        errdefer std.posix.close(fd);

        try ioctlSetInt(fd, c.UI_SET_EVBIT, c.EV_KEY);
        try ioctlSetInt(fd, c.UI_SET_EVBIT, c.EV_SYN);

        const supported_keys = [_]c_int{
            // Number row
            c.KEY_1,          c.KEY_2,          c.KEY_3,        c.KEY_4,         c.KEY_5,
            c.KEY_6,          c.KEY_7,          c.KEY_8,        c.KEY_9,         c.KEY_0,

            // Letters
            c.KEY_Q,          c.KEY_W,          c.KEY_E,        c.KEY_R,         c.KEY_T,
            c.KEY_Y,          c.KEY_U,          c.KEY_I,        c.KEY_O,         c.KEY_P,
            c.KEY_A,          c.KEY_S,          c.KEY_D,        c.KEY_F,         c.KEY_G,
            c.KEY_H,          c.KEY_J,          c.KEY_K,        c.KEY_L,         c.KEY_Z,
            c.KEY_X,          c.KEY_C,          c.KEY_V,        c.KEY_B,         c.KEY_N,
            c.KEY_M,

            // Punctuation
                     c.KEY_MINUS,      c.KEY_EQUAL,    c.KEY_LEFTBRACE, c.KEY_RIGHTBRACE,
            c.KEY_SEMICOLON,  c.KEY_APOSTROPHE, c.KEY_GRAVE,    c.KEY_BACKSLASH, c.KEY_COMMA,
            c.KEY_DOT,        c.KEY_SLASH,

            // Basic editing / whitespace
                 c.KEY_ESC,      c.KEY_TAB,       c.KEY_ENTER,
            c.KEY_BACKSPACE,  c.KEY_SPACE,

            // Modifiers
                 c.KEY_LEFTCTRL, c.KEY_RIGHTCTRL, c.KEY_LEFTSHIFT,
            c.KEY_RIGHTSHIFT, c.KEY_LEFTALT,    c.KEY_RIGHTALT, c.KEY_LEFTMETA,  c.KEY_RIGHTMETA,
            c.KEY_CAPSLOCK,

            // Navigation
              c.KEY_LEFT,       c.KEY_RIGHT,    c.KEY_UP,        c.KEY_DOWN,
            c.KEY_HOME,       c.KEY_END,        c.KEY_PAGEUP,   c.KEY_PAGEDOWN,  c.KEY_INSERT,
            c.KEY_DELETE,

            // Function keys
                c.KEY_F1,         c.KEY_F2,       c.KEY_F3,        c.KEY_F4,
            c.KEY_F5,         c.KEY_F6,         c.KEY_F7,       c.KEY_F8,        c.KEY_F9,
            c.KEY_F10,        c.KEY_F11,        c.KEY_F12,

            // Numpad
                 c.KEY_KP0,       c.KEY_KP1,
            c.KEY_KP2,        c.KEY_KP3,        c.KEY_KP4,      c.KEY_KP5,       c.KEY_KP6,
            c.KEY_KP7,        c.KEY_KP8,        c.KEY_KP9,      c.KEY_KPENTER,   c.KEY_KPPLUS,
            c.KEY_KPMINUS,    c.KEY_KPASTERISK, c.KEY_KPSLASH,  c.KEY_KPDOT,
        };

        for (supported_keys) |key_code| {
            try ioctlSetInt(fd, c.UI_SET_KEYBIT, key_code);
        }

        var dev: c.struct_uinput_setup = std.mem.zeroes(c.struct_uinput_setup);
        dev.id.bustype = c.BUS_USB;
        dev.id.vendor = 0x1234;
        dev.id.product = 0x5678;
        dev.id.version = 1;

        const name = "tartarusd virtual keyboard";
        @memcpy(dev.name[0..name.len], name);

        if (c.ioctl(fd, c.UI_DEV_SETUP, @intFromPtr(&dev)) < 0) {
            return error.UinputSetupFailed;
        }

        if (c.ioctl(fd, c.UI_DEV_CREATE, @as(c_int, 0)) < 0) {
            return error.UinputCreateFailed;
        }

        std.Thread.sleep(100 * std.time.ns_per_ms);

        return .{ .fd = fd };
    }

    pub fn destroy(self: *VirtualKeyboard) void {
        _ = c.ioctl(self.fd, c.UI_DEV_DESTROY, @as(c_int, 0));
        std.posix.close(self.fd);
    }

    pub fn sendKey(self: *VirtualKeyboard, key_code: u16, pressed: bool) !void {
        try self.emit(c.EV_KEY, key_code, if (pressed) 1 else 0);
        try self.sync();
    }

    pub fn sendCombo(self: *VirtualKeyboard, key_codes: []const u16) !void {
        if (key_codes.len == 0) return;

        for (key_codes) |key_code| {
            try self.emit(c.EV_KEY, key_code, 1);
        }
        try self.sync();

        var i: usize = key_codes.len;
        while (i > 0) {
            i -= 1;
            try self.emit(c.EV_KEY, key_codes[i], 0);
        }
        try self.sync();
    }

    pub fn sync(self: *VirtualKeyboard) !void {
        try self.emit(c.EV_SYN, c.SYN_REPORT, 0);
    }

    fn emit(self: *VirtualKeyboard, event_type: u16, code: u16, value: i32) !void {
        var ev: c.struct_input_event = std.mem.zeroes(c.struct_input_event);
        ev.type = event_type;
        ev.code = code;
        ev.value = value;

        const bytes = std.mem.asBytes(&ev);
        var written: usize = 0;
        while (written < bytes.len) {
            const amt = try std.posix.write(self.fd, bytes[written..]);
            written += amt;
        }
    }
};

fn ioctlSetInt(fd: std.posix.fd_t, req: c_ulong, value: c_int) !void {
    if (c.ioctl(fd, req, value) < 0) {
        return error.UinputIoctlFailed;
    }
}
