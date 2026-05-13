const std = @import("std");
const model = @import("common").model;
const log = @import("common").log;
const state_mod = @import("daemon_support").state;
const handler = @import("daemon_support").handler;
const reload_signal = @import("daemon_support").reload_signal;
const config = @import("config");
const device = @import("device");
const linux = @import("linux");

const OpenDevice = struct {
    path: []u8,
    fd: std.posix.fd_t,
};

fn openTartarusDevices(allocator: std.mem.Allocator) ![]OpenDevice {
    const paths = try linux.input_inspect.findTartarusEventPaths(allocator);
    errdefer {
        for (paths) |path| allocator.free(path);
        allocator.free(paths);
    }

    if (paths.len == 0) return error.TartarusNotFound;

    const devices = try allocator.alloc(OpenDevice, paths.len);
    errdefer allocator.free(devices);

    var opened: usize = 0;
    errdefer {
        var i: usize = 0;
        while (i < opened) : (i += 1) {
            _ = std.c.close(devices[i].fd);
            allocator.free(devices[i].path);
        }
    }

    for (paths, 0..) |path, idx| {
        const fd = try device.evdev.openEventDevice(path);
        devices[idx] = .{
            .path = path,
            .fd = fd,
        };
        opened += 1;
    }

    allocator.free(paths);
    return devices;
}

fn closeOpenDevices(allocator: std.mem.Allocator, devices: []OpenDevice) void {
    for (devices) |dev| {
        _ = std.c.close(dev.fd);
        allocator.free(dev.path);
    }
    allocator.free(devices);
}

fn grabAllDevices(devices: []OpenDevice) !void {
    var grabbed: usize = 0;
    errdefer {
        var i: usize = 0;
        while (i < grabbed) : (i += 1) {
            device.evdev.ungrabDevice(devices[i].fd);
        }
    }

    for (devices) |*dev| {
        try device.evdev.grabDevice(dev.fd);
        grabbed += 1;
    }
}

fn ungrabAllDevices(devices: []OpenDevice) void {
    for (devices) |*dev| {
        device.evdev.ungrabDevice(dev.fd);
    }
}

fn waitForReadableDeviceIndex(
    allocator: std.mem.Allocator,
    devices: []OpenDevice,
    timeout_ms: i32,
) !?usize {
    const pollfds = try allocator.alloc(std.posix.pollfd, devices.len);
    defer allocator.free(pollfds);

    for (devices, 0..) |dev, i| {
        pollfds[i] = .{
            .fd = dev.fd,
            .events = std.posix.POLL.IN,
            .revents = 0,
        };
    }

    const rc = try std.posix.poll(pollfds, timeout_ms);
    if (rc == 0) return null;

    for (pollfds, 0..) |pfd, i| {
        if ((pfd.revents & std.posix.POLL.IN) != 0) {
            return i;
        }
    }

    return null;
}

/// Main event loop: opens and polls all discovered Tartarus event devices.
pub fn runLiveEventLoop(
    allocator: std.mem.Allocator,
    io: std.Io,
    current_cfg: *model.ConfigModel,
    state: *state_mod.State,
) !void {
    const devices = try openTartarusDevices(allocator);
    defer closeOpenDevices(allocator, devices);

    grabAllDevices(devices) catch |err| {
        log.info("failed to grab Tartarus devices; another tartarusd instance may already be running\n", .{});
        return err;
    };
    defer ungrabAllDevices(devices);

    log.info("starting live evdev loop on Tartarus devices\n", .{});
    log.info("device grab: enabled\n", .{});
    log.info("press Ctrl+C to stop\n", .{});
    log.info("send SIGHUP to reload config\n", .{});
    log.verbose("devices:\n", .{});
    for (devices) |dev| {
        log.verbose("  {s}\n", .{dev.path});
    }

    while (true) {
        if (reload_signal.consumeReloadRequest()) {
            log.info("reload: requested\n", .{});

            const detailed = config.runtime.loadDefaultParsedConfigDetailed(allocator) catch |err| {
                log.info("reload: failed: {s}\n", .{@errorName(err)});
                continue;
            };

            switch (detailed) {
                .success => |new_cfg| {
                    const old_cfg = current_cfg.*;
                    current_cfg.* = new_cfg;
                    state.* = state_mod.State.init(current_cfg.*);
                    config.free.freeConfigModel(allocator, old_cfg);

                    log.info(
                        "reload: success default_layer={s} layer_count={}\n",
                        .{ state.cfg.default_layer, state.cfg.layers.len },
                    );
                },
                .parse_error => |info| {
                    defer allocator.free(info.line_contents);
                    log.info("reload: config invalid\n", .{});
                    config.runtime.printParseError(info);
                },
            }
        }

        const ready_index = try waitForReadableDeviceIndex(allocator, devices, 100);
        if (ready_index == null) continue;

        const idx = ready_index.?;
        const physical = try device.evdev.readPhysicalEvent(devices[idx].fd) orelse continue;

        log.verbose(
            "physical event: device={s} control={s} trigger={s} active_layer_before={s}\n",
            .{ devices[idx].path, physical.control_id, @tagName(physical.trigger), state.active_layer },
        );

        const logical = device.translate.translatePhysicalEvent(physical) orelse {
            log.verbose("  translator dropped unmapped control\n", .{});
            continue;
        };

        log.verbose(
            "  translated -> logical_key={s} trigger={s}\n",
            .{ logical.logical_key, @tagName(logical.trigger) },
        );

        handler.handleEvent(allocator, io, state, logical) catch |err| {
            log.verbose("  handler error: {s}\n", .{@errorName(err)});
            continue;
        };

        log.verbose("  active_layer_after={s}\n", .{state.active_layer});
    }
}
