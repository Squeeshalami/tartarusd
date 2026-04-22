const std = @import("std");
const model = @import("common").model;

pub const DeviceMapEntry = struct {
    control_id: []const u8,
    logical_key: []const u8,
};

const tartarus_v2_entries = [_]DeviceMapEntry{
    .{ .control_id = "main_01", .logical_key = "main_01" },
    .{ .control_id = "main_02", .logical_key = "main_02" },
    .{ .control_id = "main_03", .logical_key = "main_03" },
    .{ .control_id = "main_04", .logical_key = "main_04" },
    .{ .control_id = "main_05", .logical_key = "main_05" },

    .{ .control_id = "main_06", .logical_key = "main_06" },
    .{ .control_id = "main_07", .logical_key = "main_07" },
    .{ .control_id = "main_08", .logical_key = "main_08" },
    .{ .control_id = "main_09", .logical_key = "main_09" },
    .{ .control_id = "main_10", .logical_key = "main_10" },

    .{ .control_id = "main_11", .logical_key = "main_11" },
    .{ .control_id = "main_12", .logical_key = "main_12" },
    .{ .control_id = "main_13", .logical_key = "main_13" },
    .{ .control_id = "main_14", .logical_key = "main_14" },
    .{ .control_id = "main_15", .logical_key = "main_15" },

    .{ .control_id = "main_16", .logical_key = "main_16" },
    .{ .control_id = "main_17", .logical_key = "main_17" },
    .{ .control_id = "main_18", .logical_key = "main_18" },
    .{ .control_id = "main_19", .logical_key = "main_19" },
    .{ .control_id = "main_20", .logical_key = "main_20" },

    .{ .control_id = "dpad_up", .logical_key = "dpad_up" },
    .{ .control_id = "dpad_left", .logical_key = "dpad_left" },
    .{ .control_id = "dpad_right", .logical_key = "dpad_right" },
    .{ .control_id = "dpad_down", .logical_key = "dpad_down" },

    .{ .control_id = "thumb_button_1", .logical_key = "thumb_button_1" },

    .{ .control_id = "scroll_up", .logical_key = "scroll_up" },
    .{ .control_id = "scroll_down", .logical_key = "scroll_down" },
};

pub fn mapControlToLogicalKey(control_id: []const u8) ?[]const u8 {
    for (tartarus_v2_entries) |entry| {
        if (std.mem.eql(u8, entry.control_id, control_id)) {
            return entry.logical_key;
        }
    }
    return null;
}

pub fn entries() []const DeviceMapEntry {
    return &tartarus_v2_entries;
}

pub fn decodeEvdevKeyEvent(code: u16, value: i32) ?model.PhysicalInputEvent {
    const trigger: model.Trigger = switch (value) {
        0 => .release,
        1 => .press,
        2 => .repeat,
        else => return null,
    };

    const control_id = switch (code) {
        2 => "main_01",
        3 => "main_02",
        4 => "main_03",
        5 => "main_04",
        6 => "main_05",

        15 => "main_06",
        16 => "main_07",
        17 => "main_08",
        18 => "main_09",
        19 => "main_10",

        58 => "main_11",
        30 => "main_12",
        31 => "main_13",
        32 => "main_14",
        33 => "main_15",

        42 => "main_16",
        44 => "main_17",
        45 => "main_18",
        46 => "main_19",
        57 => "main_20",

        103 => "dpad_up",
        105 => "dpad_left",
        106 => "dpad_right",
        108 => "dpad_down",

        56 => "thumb_button_1",
        else => return null,
    };

    return .{
        .control_id = control_id,
        .trigger = trigger,
    };
}
