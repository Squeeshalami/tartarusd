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
        \\  tartarusctl init
        \\  tartarusctl status
        \\  tartarusctl validate
        \\  tartarusctl reload
        \\  tartarusctl quit
        \\  tartarusctl lookup <layer> <logical-key>
        \\  tartarusctl discover
        \\
        \\For command details:
        \\  tartarusctl <command> help
        \\
    , .{});
}

pub fn printCommandHelp(cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, "init")) {
        std.debug.print(
            \\init
            \\  Creates a starter configuration file in ~/.config/tartarusd/ when missing.
            \\
            \\Usage:
            \\  tartarusctl init
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "status")) {
        std.debug.print(
            \\status
            \\  Shows a health report for daemon state, config, device detection, and uinput access.
            \\
            \\Usage:
            \\  tartarusctl status
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "validate")) {
        std.debug.print(
            \\validate
            \\  Parses the config and prints either success or detailed parse errors.
            \\
            \\Usage:
            \\  tartarusctl validate
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "lookup")) {
        std.debug.print(
            \\lookup
            \\  Resolves one logical key binding from a specific layer and prints the mapped action.
            \\
            \\Usage:
            \\  tartarusctl lookup <layer> <logical-key>
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "discover")) {
        std.debug.print(
            \\discover
            \\  Finds /dev/input/event* nodes that look like a Razer Tartarus device.
            \\
            \\Usage:
            \\  tartarusctl discover
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "reload")) {
        std.debug.print(
            \\reload
            \\  Sends SIGHUP to running tartarusd processes so they reload configuration.
            \\
            \\Usage:
            \\  tartarusctl reload
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "quit")) {
        std.debug.print(
            \\quit
            \\  Sends SIGTERM to running tartarusd processes to stop the daemon.
            \\
            \\Usage:
            \\  tartarusctl quit
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "list-input-devices")) {
        std.debug.print(
            \\list-input-devices
            \\  Debug command that lists all /dev/input/event* nodes and their device names.
            \\
            \\Usage:
            \\  tartarusctl list-input-devices
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "inspect-device")) {
        std.debug.print(
            \\inspect-device
            \\  Debug command that prints metadata for a specific event device node.
            \\
            \\Usage:
            \\  tartarusctl inspect-device <event_path>
            \\
        , .{});
        return true;
    }

    if (std.mem.eql(u8, cmd, "monitor-device")) {
        std.debug.print(
            \\monitor-device
            \\  Debug command that streams raw input events from a specific event node.
            \\
            \\Usage:
            \\  tartarusctl monitor-device <event_path>
            \\
        , .{});
        return true;
    }

    return false;
}

fn printReportSection(title: []const u8) void {
    std.debug.print("\n{s}\n", .{title});
}

fn printReportCheck(ok: bool, label: []const u8, detail: []const u8) void {
    std.debug.print("  - {s}", .{label});
    if (detail.len > 0) {
        std.debug.print(": {s}", .{detail});
    }
    if (!ok) {
        std.debug.print(" (failed)", .{});
    }
    std.debug.print("\n", .{});
}

fn printReportDetail(detail: []const u8) void {
    std.debug.print("         - {s}\n", .{detail});
}

pub fn handleStatus(allocator: std.mem.Allocator, io: std.Io, config_path: []const u8) !void {
    std.debug.print("Status Report\n", .{});
    std.debug.print("----------------------------------------\n", .{});

    var checks_total: usize = 0;
    var checks_passed: usize = 0;

    printReportSection("Daemon");
    const pids = daemon_control.findDaemonPids(allocator, io) catch |err| {
        checks_total += 1;
        printReportCheck(false, "Daemon status query", @errorName(err));
        std.debug.print("\nSummary: {}/{} checks passed\n", .{ checks_passed, checks_total });
        return;
    };
    defer allocator.free(pids);

    checks_total += 1;
    if (pids.len == 0) {
        printReportCheck(false, "Daemon running", "not running");
    } else {
        checks_passed += 1;
        std.debug.print("  - Daemon running: pids ", .{});
        for (pids, 0..) |pid, idx| {
            if (idx > 0) std.debug.print(",", .{});
            std.debug.print("{}", .{pid});
        }
        std.debug.print("\n", .{});
    }

    printReportSection("Configuration");
    const has_config = config.validate.configExists(config_path);
    checks_total += 1;
    if (has_config) checks_passed += 1;
    printReportCheck(has_config, "Config file available", config_path);

    printReportSection("Input Devices");
    const device_paths = linux.input_inspect.findTartarusEventPaths(allocator) catch |err| {
        checks_total += 1;
        printReportCheck(false, "Tartarus device detection", @errorName(err));
        std.debug.print("\nSummary: {}/{} checks passed\n", .{ checks_passed, checks_total });
        return;
    };
    defer {
        for (device_paths) |device_path| allocator.free(device_path);
        allocator.free(device_paths);
    }

    const has_devices = device_paths.len > 0;
    checks_total += 1;
    if (has_devices) checks_passed += 1;
    if (has_devices) {
        const detail = try std.fmt.allocPrint(allocator, "{} detected", .{device_paths.len});
        defer allocator.free(detail);
        printReportCheck(true, "Tartarus event devices found", detail);
    } else {
        printReportCheck(false, "Tartarus event devices found", "none detected");
    }

    for (device_paths) |device_path| {
        const readable = blk: {
            const fd = std.posix.openat(std.os.linux.AT.FDCWD, device_path, .{ .CLOEXEC = true }, 0) catch {
                break :blk false;
            };
            _ = std.c.close(fd);
            break :blk true;
        };

        checks_total += 1;
        if (readable) checks_passed += 1;

        const access = if (readable) "readable" else "cannot open";
        const detail = try std.fmt.allocPrint(allocator, "{s} ({s})", .{ device_path, access });
        defer allocator.free(detail);
        printReportCheck(readable, "Device node access", detail);
    }

    printReportSection("Uinput");
    const uinput_path = "/dev/uinput";

    var uinput_exists = false;
    const uinput_rw = blk: {
        const fd = std.posix.openat(std.os.linux.AT.FDCWD, uinput_path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch |err| switch (err) {
            error.FileNotFound => {
                uinput_exists = false;
                break :blk false;
            },
            error.AccessDenied => {
                uinput_exists = true;
                break :blk false;
            },
            else => {
                uinput_exists = false;
                break :blk false;
            },
        };
        _ = std.c.close(fd);
        uinput_exists = true;
        break :blk true;
    };

    checks_total += 1;
    if (uinput_exists) checks_passed += 1;
    printReportCheck(uinput_exists, "/dev/uinput exists", uinput_path);

    checks_total += 1;
    if (uinput_rw) checks_passed += 1;
    const uinput_access = if (uinput_rw) "read/write OK" else "read/write unavailable";
    printReportCheck(uinput_rw, "/dev/uinput access", uinput_access);

    std.debug.print("\nSummary: {}/{} checks passed\n", .{ checks_passed, checks_total });
    if (checks_passed == checks_total) {
        printReportDetail("System looks healthy.");
    } else {
        printReportDetail("Check the failed items above.");
    }
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
