const model = @import("common").model;

pub fn getSampleConfig() model.ConfigModel {
    const base_bindings = [_]model.Binding{
        .{
            .logical_key = "main_01",
            .action = .{ .key = .{
                .key = "1",
            } },
        },
        .{
            .logical_key = "main_02",
            .action = .{ .combo = .{
                .keys = &[_][]const u8{ "ctrl", "shift", "p" },
            } },
        },
        .{
            .logical_key = "main_03",
            .action = .{ .exec = .{
                .program = "ghostty",
                .args = &[_][]const u8{},
            } },
        },
        .{
            .logical_key = "main_04",
            .action = .{ .command = .{
                .shell = "playerctl play-pause",
                .detach = true,
                .cooldown_ms = 0,
            } },
        },
        .{
            .logical_key = "main_05",
            .action = .{ .layer = .{
                .target = "nav",
                .mode = .hold,
            } },
        },
        .{
            .logical_key = "main_06",
            .action = .{ .layer = .{
                .target = "nav",
                .mode = .toggle,
            } },
        },
    };

    const nav_bindings = [_]model.Binding{
        .{
            .logical_key = "main_01",
            .action = .{ .key = .{
                .key = "up",
            } },
        },
        .{
            .logical_key = "main_02",
            .action = .{ .key = .{
                .key = "left",
            } },
        },
        .{
            .logical_key = "main_03",
            .action = .{ .key = .{
                .key = "down",
            } },
        },
        .{
            .logical_key = "main_04",
            .action = .{ .key = .{
                .key = "right",
            } },
        },
        .{
            .logical_key = "dpad_up",
            .action = .{ .key = .{
                .key = "up",
            } },
        },
        .{
            .logical_key = "dpad_left",
            .action = .{ .key = .{
                .key = "left",
            } },
        },
        .{
            .logical_key = "dpad_right",
            .action = .{ .key = .{
                .key = "right",
            } },
        },
        .{
            .logical_key = "dpad_down",
            .action = .{ .key = .{
                .key = "down",
            } },
        },
        .{
            .logical_key = "thumb_button_1",
            .action = .{ .key = .{
                .key = "enter",
            } },
        },
    };

    const layers = [_]model.Layer{
        .{
            .name = "base",
            .bindings = &base_bindings,
        },
        .{
            .name = "nav",
            .bindings = &nav_bindings,
        },
    };

    return .{
        .default_layer = "base",
        .layers = &layers,
    };
}
