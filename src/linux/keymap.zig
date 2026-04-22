const std = @import("std");

pub const KeyEntry = struct {
    name: []const u8,
    code: u16,
};

const keys = [_]KeyEntry{
    // Number row
    .{ .name = "1", .code = 2 },
    .{ .name = "2", .code = 3 },
    .{ .name = "3", .code = 4 },
    .{ .name = "4", .code = 5 },
    .{ .name = "5", .code = 6 },
    .{ .name = "6", .code = 7 },
    .{ .name = "7", .code = 8 },
    .{ .name = "8", .code = 9 },
    .{ .name = "9", .code = 10 },
    .{ .name = "0", .code = 11 },

    // Letters
    .{ .name = "q", .code = 16 },
    .{ .name = "w", .code = 17 },
    .{ .name = "e", .code = 18 },
    .{ .name = "r", .code = 19 },
    .{ .name = "t", .code = 20 },
    .{ .name = "y", .code = 21 },
    .{ .name = "u", .code = 22 },
    .{ .name = "i", .code = 23 },
    .{ .name = "o", .code = 24 },
    .{ .name = "p", .code = 25 },

    .{ .name = "a", .code = 30 },
    .{ .name = "s", .code = 31 },
    .{ .name = "d", .code = 32 },
    .{ .name = "f", .code = 33 },
    .{ .name = "g", .code = 34 },
    .{ .name = "h", .code = 35 },
    .{ .name = "j", .code = 36 },
    .{ .name = "k", .code = 37 },
    .{ .name = "l", .code = 38 },

    .{ .name = "z", .code = 44 },
    .{ .name = "x", .code = 45 },
    .{ .name = "c", .code = 46 },
    .{ .name = "v", .code = 47 },
    .{ .name = "b", .code = 48 },
    .{ .name = "n", .code = 49 },
    .{ .name = "m", .code = 50 },

    // Basic punctuation / symbols
    .{ .name = "minus", .code = 12 },
    .{ .name = "-", .code = 12 },
    .{ .name = "equal", .code = 13 },
    .{ .name = "=", .code = 13 },
    .{ .name = "leftbrace", .code = 26 },
    .{ .name = "[", .code = 26 },
    .{ .name = "rightbrace", .code = 27 },
    .{ .name = "]", .code = 27 },
    .{ .name = "semicolon", .code = 39 },
    .{ .name = ";", .code = 39 },
    .{ .name = "apostrophe", .code = 40 },
    .{ .name = "'", .code = 40 },
    .{ .name = "grave", .code = 41 },
    .{ .name = "`", .code = 41 },
    .{ .name = "backslash", .code = 43 },
    .{ .name = "\\", .code = 43 },
    .{ .name = "comma", .code = 51 },
    .{ .name = ",", .code = 51 },
    .{ .name = "dot", .code = 52 },
    .{ .name = ".", .code = 52 },
    .{ .name = "slash", .code = 53 },
    .{ .name = "/", .code = 53 },

    // Whitespace / editing
    .{ .name = "esc", .code = 1 },
    .{ .name = "escape", .code = 1 },
    .{ .name = "tab", .code = 15 },
    .{ .name = "enter", .code = 28 },
    .{ .name = "return", .code = 28 },
    .{ .name = "backspace", .code = 14 },
    .{ .name = "space", .code = 57 },

    // Modifiers
    .{ .name = "ctrl", .code = 29 },
    .{ .name = "leftctrl", .code = 29 },
    .{ .name = "rightctrl", .code = 97 },
    .{ .name = "shift", .code = 42 },
    .{ .name = "leftshift", .code = 42 },
    .{ .name = "rightshift", .code = 54 },
    .{ .name = "alt", .code = 56 },
    .{ .name = "leftalt", .code = 56 },
    .{ .name = "rightalt", .code = 100 },
    .{ .name = "super", .code = 125 },
    .{ .name = "meta", .code = 125 },
    .{ .name = "leftsuper", .code = 125 },
    .{ .name = "leftmeta", .code = 125 },
    .{ .name = "rightsuper", .code = 126 },
    .{ .name = "rightmeta", .code = 126 },
    .{ .name = "capslock", .code = 58 },

    // Navigation
    .{ .name = "up", .code = 103 },
    .{ .name = "down", .code = 108 },
    .{ .name = "left", .code = 105 },
    .{ .name = "right", .code = 106 },
    .{ .name = "home", .code = 102 },
    .{ .name = "end", .code = 107 },
    .{ .name = "pageup", .code = 104 },
    .{ .name = "pagedown", .code = 109 },
    .{ .name = "insert", .code = 110 },
    .{ .name = "delete", .code = 111 },
    .{ .name = "del", .code = 111 },

    // Function keys
    .{ .name = "f1", .code = 59 },
    .{ .name = "f2", .code = 60 },
    .{ .name = "f3", .code = 61 },
    .{ .name = "f4", .code = 62 },
    .{ .name = "f5", .code = 63 },
    .{ .name = "f6", .code = 64 },
    .{ .name = "f7", .code = 65 },
    .{ .name = "f8", .code = 66 },
    .{ .name = "f9", .code = 67 },
    .{ .name = "f10", .code = 68 },
    .{ .name = "f11", .code = 87 },
    .{ .name = "f12", .code = 88 },

    // Numpad
    .{ .name = "kp0", .code = 82 },
    .{ .name = "kp1", .code = 79 },
    .{ .name = "kp2", .code = 80 },
    .{ .name = "kp3", .code = 81 },
    .{ .name = "kp4", .code = 75 },
    .{ .name = "kp5", .code = 76 },
    .{ .name = "kp6", .code = 77 },
    .{ .name = "kp7", .code = 71 },
    .{ .name = "kp8", .code = 72 },
    .{ .name = "kp9", .code = 73 },
    .{ .name = "kpenter", .code = 96 },
    .{ .name = "kpplus", .code = 78 },
    .{ .name = "kpminus", .code = 74 },
    .{ .name = "kpmultiply", .code = 55 },
    .{ .name = "kpdivide", .code = 98 },
    .{ .name = "kpdot", .code = 83 },
};

pub fn lookupKeyCode(name: []const u8) ?u16 {
    for (keys) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry.code;
        }
    }
    return null;
}
