const std = @import("std");
const AppNames = @import("common").types.AppNames;
const config = @import("config");
const print = @import("print.zig");
const mapper = @import("daemon_support").mapper;
const linux = @import("linux");
const daemon_control = @import("daemon_control.zig");
const utils = @import("utils.zig");

pub fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  tartarusctl status
        \\  tartarusctl reload
        \\  tartarusctl quit
        \\  tartarusctl config-path
        \\  tartarusctl validate
        \\  tartarusctl init-config
        \\  tartarusctl lookup <layer> <logical-key>
        \\  tartarusctl lookup-keycode <name>
        \\  tartarusctl find-tartarus
        \\  tartarusctl list-input-devices
        \\  tartarusctl inspect-device <event_path>
        \\  tartarusctl monitor-device <event_path>
        \\  tartarusctl doctor
        \\
    , .{});
}

fn printCheck(ok: bool, label: []const u8, detail: []const u8) void {
    const status = if (ok) "OK" else "FAIL";
    std.debug.print("[{s}] {s}", .{ status, label });
    if (detail.len > 0) {
        std.debug.print(": {s}", .{detail});
    }
    std.debug.print("\n", .{});
}

fn printDeviceList(label: []const u8, paths: []const []const u8) void {
    if (paths.len == 0) {
        std.debug.print("{s}: none\n", .{label});
        return;
    }

    std.debug.print("{s}:\n", .{label});
    for (paths) |path| {
        std.debug.print("  {s}\n", .{path});
    }
}

pub fn handleConfigPath(config_path: []const u8) void {
    std.debug.print("{s}\n", .{config_path});
}

pub fn handleStatus(allocator: std.mem.Allocator, io: std.Io, config_path: []const u8) !void {
    std.debug.print("{s} status\n", .{AppNames.cli});
    std.debug.print("config path: {s}\n", .{config_path});

    const pids = daemon_control.findDaemonPids(allocator, io) catch |err| {
        std.debug.print("daemon: status check failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(pids);

    if (pids.len == 0) {
        std.debug.print("daemon: not running\n", .{});
    } else {
        std.debug.print("daemon: running\n", .{});
        std.debug.print("pids:", .{});
        for (pids, 0..) |pid, idx| {
            if (idx > 0) std.debug.print(",", .{});
            std.debug.print(" {}", .{pid});
        }
        std.debug.print("\n", .{});
    }

    const device_paths = linux.input_inspect.findTartarusEventPaths(allocator) catch |err| {
        std.debug.print("devices: detection failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer {
        for (device_paths) |device_path| allocator.free(device_path);
        allocator.free(device_paths);
    }

    printDeviceList("devices", device_paths);
}

pub fn handleValidate(allocator: std.mem.Allocator, config_path: []const u8) !void {
    const detailed = config.runtime.loadParsedConfigDetailed(allocator, config_path) catch |err| {
        if (err == error.ConfigMissing) {
            std.debug.print("config missing: {s}\n", .{config_path});
            return;
        }
        return err;
    };

    switch (detailed) {
        .success => |cfg| {
            defer config.free.freeConfigModel(allocator, cfg);
            std.debug.print("config OK: {s}\n", .{config_path});
        },
        .parse_error => |info| {
            std.debug.print("config invalid: {s}\n", .{config_path});
            std.debug.print("parse error: {s} ({s})\n", .{ @tagName(info.kind), info.error_name });

            if (info.line_number > 0) {
                std.debug.print("line {}: {s}\n", .{ info.line_number, info.line_contents });
            }

            if (parseHintForKind(info.kind)) |hint| {
                std.debug.print("hint: {s}\n", .{hint});
            }
        },
    }
}

fn parseHintForKind(kind: config.parse_bindings.ParseErrorInfo.Kind) ?[]const u8 {
    return switch (kind) {
        .MissingSectionHeader => "move bindings under a [layer.<name>] section",
        .MissingEquals => "expected assignment syntax: key = value",
        .MissingRequiredField => "check required fields for this action type",
        .InvalidArrayItem => "array values must be quoted strings, e.g. [\"a\", \"b\"]",
        .UnknownActionType => "valid action types are key, combo, exec, command, layer",
        .InvalidLayerMode => "valid layer modes are set, hold, toggle",
        else => null,
    };
}

pub fn handleInitConfig(allocator: std.mem.Allocator, config_path: []const u8) !void {
    const dir_path = try config.init.ensureDefaultConfigDir(allocator);
    defer allocator.free(dir_path);

    const created = try config.write.writeFileIfMissing(
        config_path,
        config.template.default_config,
    );

    if (created) {
        std.debug.print("created config directory: {s}\n", .{dir_path});
        std.debug.print("created config file: {s}\n", .{config_path});
    } else {
        std.debug.print("config already exists: {s}\n", .{config_path});
    }
}

pub fn handleLookup(
    allocator: std.mem.Allocator,
    config_path: []const u8,
    args: []const []const u8,
) !void {
    if (args.len < 4) {
        std.debug.print("lookup requires: <layer> <logical-key>\n\n", .{});
        printUsage();
        return;
    }

    const layer_name = args[2];
    const logical_key = args[3];
    const cfg = utils.loadParsedConfig(allocator, config_path) catch |err| {
        if (err == error.ConfigMissing) {
            std.debug.print("config missing: {s}\n", .{config_path});
            return;
        }
        return err;
    };
    defer config.free.freeConfigModel(allocator, cfg);

    const action = mapper.lookupAction(cfg, layer_name, logical_key) orelse {
        std.debug.print(
            "no binding found for layer={s} key={s}\n",
            .{ layer_name, logical_key },
        );
        return;
    };

    std.debug.print(
        "resolved binding: layer={s} key={s} -> ",
        .{ layer_name, logical_key },
    );
    print.printAction(action);
    std.debug.print("\n", .{});
}

pub fn handleListInputDevices(allocator: std.mem.Allocator) !void {
    const devices = linux.input_list.listEventDevicePaths(allocator) catch |err| {
        std.debug.print("failed to list input devices: {s}\n", .{@errorName(err)});
        return;
    };
    defer linux.input_list.freeDeviceEntries(allocator, devices);

    if (devices.len == 0) {
        std.debug.print("no /dev/input/event* devices found\n", .{});
        return;
    }

    std.debug.print("input event devices:\n", .{});
    for (devices) |device| {
        std.debug.print("  {s}  ->  {s}\n", .{ device.path, device.name });
    }
}

pub fn handleInspectDevice(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("inspect-device requires: <event_path>\n\n", .{});
        printUsage();
        return;
    }

    const event_path = args[2];
    const info = linux.input_inspect.inspectEventDevice(allocator, event_path) catch |err| {
        std.debug.print(
            "failed to inspect device {s}: {s}\n",
            .{ event_path, @errorName(err) },
        );
        return;
    };
    defer linux.input_inspect.freeDeviceInfo(allocator, info);

    std.debug.print("device inspection:\n", .{});
    std.debug.print("  event path:   {s}\n", .{info.event_path});
    std.debug.print("  event name:   {s}\n", .{info.event_name});
    std.debug.print("  device name:  {s}\n", .{info.device_name});
    std.debug.print("  sysfs path:   {s}\n", .{info.sysfs_device_path});

    if (info.vendor_id) |vendor| {
        std.debug.print("  vendor id:    {s}\n", .{vendor});
    } else {
        std.debug.print("  vendor id:    <unknown>\n", .{});
    }

    if (info.product_id) |product| {
        std.debug.print("  product id:   {s}\n", .{product});
    } else {
        std.debug.print("  product id:   <unknown>\n", .{});
    }
}

pub fn handleMonitorDevice(args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("monitor-device requires: <event_path>\n\n", .{});
        printUsage();
        return;
    }

    const event_path = args[2];
    linux.evdev_monitor.monitorDevice(event_path) catch |err| {
        std.debug.print(
            "failed to monitor device {s}: {s}\n",
            .{ event_path, @errorName(err) },
        );
    };
}

pub fn handleFindTartarus(allocator: std.mem.Allocator) !void {
    const paths = linux.input_inspect.findTartarusEventPaths(allocator) catch |err| {
        std.debug.print("failed to find Tartarus devices: {s}\n", .{@errorName(err)});
        return;
    };
    defer {
        for (paths) |path| allocator.free(path);
        allocator.free(paths);
    }

    if (paths.len == 0) {
        std.debug.print("no Tartarus event nodes found\n", .{});
        return;
    }

    std.debug.print("found Tartarus event nodes:\n", .{});
    for (paths) |path| {
        std.debug.print("  {s}\n", .{path});
    }
}

pub fn handleLookupKeycode(args: []const []const u8) void {
    if (args.len < 3) {
        std.debug.print("lookup-keycode requires: <name>\n\n", .{});
        printUsage();
        return;
    }

    const name = args[2];
    const code = linux.keymap.lookupKeyCode(name) orelse {
        std.debug.print("unknown key name: {s}\n", .{name});
        return;
    };

    std.debug.print("keycode: {s} -> {}\n", .{ name, code });
}

pub fn handleReload(allocator: std.mem.Allocator, io: std.Io) !void {
    const pids = daemon_control.findDaemonPids(allocator, io) catch |err| {
        std.debug.print("failed to find tartarusd process: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(pids);

    if (pids.len == 0) {
        std.debug.print("tartarusd is not running\n", .{});
        return;
    }

    daemon_control.reloadDaemonPids(pids) catch |err| {
        switch (err) {
            error.PermissionDenied => {
                std.debug.print("permission denied sending SIGHUP; try running with sudo\n", .{});
            },
            else => {
                std.debug.print("failed to reload tartarusd: {s}\n", .{@errorName(err)});
            },
        }
        return;
    };

    std.debug.print("reloaded tartarusd", .{});
    std.debug.print(" (pids:", .{});
    for (pids, 0..) |pid, idx| {
        if (idx > 0) std.debug.print(",", .{});
        std.debug.print(" {}", .{pid});
    }
    std.debug.print(")\n", .{});
}

pub fn handleQuit(allocator: std.mem.Allocator, io: std.Io) !void {
    const pids = daemon_control.findDaemonPids(allocator, io) catch |err| {
        std.debug.print("failed to find tartarusd process: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(pids);

    if (pids.len == 0) {
        std.debug.print("tartarusd is not running\n", .{});
        return;
    }

    daemon_control.quitDaemonPids(pids) catch |err| {
        switch (err) {
            error.PermissionDenied => {
                std.debug.print("permission denied sending SIGTERM; try running with sudo\n", .{});
            },
            else => {
                std.debug.print("failed to stop tartarusd: {s}\n", .{@errorName(err)});
            },
        }
        return;
    };

    std.debug.print("stopped tartarusd", .{});
    std.debug.print(" (pids:", .{});
    for (pids, 0..) |pid, idx| {
        if (idx > 0) std.debug.print(",", .{});
        std.debug.print(" {}", .{pid});
    }
    std.debug.print(")\n", .{});
}

pub fn handleDoctor(allocator: std.mem.Allocator, io: std.Io, config_path: []const u8) !void {
    std.debug.print("{s} doctor\n\n", .{AppNames.cli});

    // Config file
    if (config.validate.configExists(config_path)) {
        printCheck(true, "config file exists", config_path);
    } else {
        printCheck(false, "config file missing", config_path);
    }

    // Tartarus device detection
    const device_paths = linux.input_inspect.findTartarusEventPaths(allocator) catch |err| {
        std.debug.print("[FAIL] Tartarus device detection failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer {
        for (device_paths) |device_path| allocator.free(device_path);
        allocator.free(device_paths);
    }

    if (device_paths.len == 0) {
        printCheck(false, "Tartarus devices found", "not found");
    } else {
        printCheck(true, "Tartarus devices found", "");
        for (device_paths) |device_path| {
            const readable = blk: {
                const fd = std.posix.openat(std.os.linux.AT.FDCWD, device_path, .{ .CLOEXEC = true }, 0) catch {
                    break :blk false;
                };
                _ = std.c.close(fd);
                break :blk true;
            };

            const status = if (readable) "OK" else "FAIL";
            std.debug.print("[{s}] device: {s}\n", .{ status, device_path });
        }
    }

    // /dev/uinput existence + rw access
    const uinput_path = "/dev/uinput";

    const uinput_rw = blk: {
        const fd = std.posix.openat(std.os.linux.AT.FDCWD, uinput_path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch |err| switch (err) {
            error.FileNotFound => {
                printCheck(false, "/dev/uinput exists", uinput_path);
                break :blk false;
            },
            error.AccessDenied => {
                printCheck(true, "/dev/uinput exists", uinput_path);
                break :blk false;
            },
            else => {
                printCheck(false, "/dev/uinput check failed", uinput_path);
                break :blk false;
            },
        };
        _ = std.c.close(fd);
        printCheck(true, "/dev/uinput exists", uinput_path);
        break :blk true;
    };

    printCheck(uinput_rw, "/dev/uinput readable/writable", "");

    // Daemon running
    const pids = daemon_control.findDaemonPids(allocator, io) catch |err| {
        std.debug.print("[FAIL] daemon status check failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(pids);

    if (pids.len == 0) {
        printCheck(false, "daemon running", "not running");
    } else {
        std.debug.print("[OK] daemon running: ", .{});
        for (pids, 0..) |pid, idx| {
            if (idx > 0) std.debug.print(",", .{});
            std.debug.print("{}", .{pid});
        }
        std.debug.print("\n", .{});
    }
}
