const std = @import("std");
const AppNames = @import("common").types.AppNames;
const log = @import("common").log;
const config = @import("config");
const state_mod = @import("daemon_support").state;
const run_live = @import("daemon_support").run_live;
const executor = @import("daemon_support").executor;
const reload_signal = @import("daemon_support").reload_signal;
const process_check = @import("daemon_support").process_check;

fn printUsage() void {
    std.debug.print(
        \\usage:
        \\  tartarusd
        \\  tartarusd --dry-run
        \\  tartarusd --verbose
        \\
    , .{});
}

fn checkExistingDaemon(allocator: std.mem.Allocator, io: std.Io) !void {
    const existing_pids = try process_check.findDaemonPids(allocator, io);
    defer allocator.free(existing_pids);

    if (existing_pids.len > 1) {
        std.debug.print("tartarusd appears to already be running\n", .{});
        std.debug.print("existing pids:", .{});
        for (existing_pids, 0..) |pid, idx| {
            if (idx > 0) std.debug.print(",", .{});
            std.debug.print(" {}", .{pid});
        }
        std.debug.print("\n", .{});
        return error.DaemonAlreadyRunning;
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var dry_run = false;
    var verbose = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "--dry-run")) {
            dry_run = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
            continue;
        }
    }

    log.setVerbose(verbose);

    try reload_signal.install();

    const path = try config.path.getDefaultConfigPath(allocator);
    defer allocator.free(path);

    log.info("{s}: starting\n", .{AppNames.daemon});
    log.info("config path: {s}\n", .{path});

    const detailed = config.runtime.loadParsedConfigDetailed(allocator, path) catch |err| {
        if (err == error.ConfigMissing) {
            std.debug.print("config missing: {s}\n", .{path});
            return;
        }
        return err;
    };

    var current_cfg = switch (detailed) {
        .success => |cfg| cfg,
        .parse_error => |info| {
            defer allocator.free(info.line_contents);
            std.debug.print("config invalid: {s}\n", .{path});
            config.runtime.printParseError(info);
            return;
        },
    };
    defer config.free.freeConfigModel(allocator, current_cfg);

    checkExistingDaemon(allocator, init.io) catch |err| {
        if (err == error.DaemonAlreadyRunning) {
            return;
        }
        return err;
    };

    executor.setDryRun(dry_run);
    try executor.initOutput();
    defer executor.shutdownOutput();

    log.info("loaded config successfully\n", .{});
    log.info("default layer: {s}\n", .{current_cfg.default_layer});
    log.info("layer count: {}\n", .{current_cfg.layers.len});

    var state = state_mod.State.init(current_cfg);

    log.info("mode: live\n", .{});
    log.info("dry-run: {}\n", .{dry_run});

    try run_live.runLiveEventLoop(allocator, init.io, &current_cfg, &state);
}
