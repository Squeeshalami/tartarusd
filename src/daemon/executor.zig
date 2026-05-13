const std = @import("std");
const model = @import("common").model;
const log = @import("common").log;
const user_context = @import("common").user_context;
const linux = @import("linux");
const keymap = @import("linux").keymap;

var virtual_keyboard: ?linux.uinput.VirtualKeyboard = null;
var dry_run_enabled: bool = false;

pub fn setDryRun(enabled: bool) void {
    dry_run_enabled = enabled;
}

pub fn isDryRun() bool {
    return dry_run_enabled;
}

pub fn initOutput() !void {
    if (dry_run_enabled) {
        log.info("DRY-RUN output initialization skipped\n", .{});
        return;
    }

    if (virtual_keyboard == null) {
        virtual_keyboard = try linux.uinput.VirtualKeyboard.create();
        log.verbose("uinput: virtual keyboard created\n", .{});
    }
}

pub fn shutdownOutput() void {
    if (dry_run_enabled) return;

    if (virtual_keyboard) |*vk| {
        vk.destroy();
        virtual_keyboard = null;
        log.verbose("uinput: virtual keyboard destroyed\n", .{});
    }
}

pub fn executeAction(allocator: std.mem.Allocator, io: std.Io, action: model.Action) !void {
    switch (action) {
        .key => |a| {
            try executeKeyAction(a);
        },
        .combo => |a| {
            try executeComboAction(allocator, a);
        },
        .exec => |a| {
            try executeProgramAsUser(allocator, io, a.program, a.args);
        },
        .command => |a| {
            try executeShellCommandAsUser(allocator, io, a.shell, a.detach);
        },
        .layer => |a| {
            std.debug.print(
                "SIMULATE layer action: target={s} mode={s}\n",
                .{ a.target, @tagName(a.mode) },
            );
        },
    }
}

fn executeKeyAction(action: model.KeyAction) !void {
    const key_code = mapKeyNameToLinuxCode(action.key) orelse return error.UnsupportedKeyName;
    const pressed = switch (action.trigger) {
        .press => true,
        .release => false,
        .repeat => return,
    };

    if (dry_run_enabled) {
        log.info(
            "DRY-RUN key: key={s} linux_code={} trigger={s}\n",
            .{ action.key, key_code, @tagName(action.trigger) },
        );
        return;
    }

    log.info(
        "INJECT key: key={s} linux_code={} trigger={s}\n",
        .{ action.key, key_code, @tagName(action.trigger) },
    );

    const vk = virtual_keyboard orelse return error.OutputNotInitialized;
    var keyboard = vk;
    try keyboard.sendKey(key_code, pressed);
}

fn executeComboAction(
    allocator: std.mem.Allocator,
    action: model.ComboAction,
) !void {
    if (action.trigger != .press) return;

    const codes = try allocator.alloc(u16, action.keys.len);
    defer allocator.free(codes);

    for (action.keys, 0..) |key_name, i| {
        codes[i] = mapKeyNameToLinuxCode(key_name) orelse return error.UnsupportedKeyName;
    }

    if (dry_run_enabled) {
        log.info("DRY-RUN combo: ", .{});
        for (action.keys, 0..) |key_name, i| {
            if (i > 0) log.info("+", .{});
            log.info("{s}", .{key_name});
        }
        log.info("\n", .{});
        return;
    }

    log.info("INJECT combo: ", .{});
    for (action.keys, 0..) |key_name, i| {
        if (i > 0) log.info("+", .{});
        log.info("{s}", .{key_name});
    }
    log.info("\n", .{});

    const vk = virtual_keyboard orelse return error.OutputNotInitialized;
    var keyboard = vk;
    try keyboard.sendCombo(codes);
}

fn mapKeyNameToLinuxCode(name: []const u8) ?u16 {
    return keymap.lookupKeyCode(name);
}

fn executeProgramAsUser(
    allocator: std.mem.Allocator,
    io: std.Io,
    program: []const u8,
    args: []const []const u8,
) !void {
    const maybe_user = try user_context.detectExecutionUser(allocator);
    defer if (maybe_user) |ctx| user_context.freeUserContext(allocator, ctx);

    const argv = try buildArgv(allocator, program, args);
    defer allocator.free(argv);

    if (maybe_user) |ctx| {
        log.info(
            "EXEC program: program={s} user={s} uid={} gid={}",
            .{ program, ctx.username, ctx.uid, ctx.gid },
        );
        if (args.len > 0) {
            log.info(" args=[", .{});
            for (args, 0..) |arg, i| {
                if (i > 0) log.info(", ", .{});
                log.info("{s}", .{arg});
            }
            log.info("]", .{});
        }
        log.info("\n", .{});

        if (dry_run_enabled) {
            log.info("DRY-RUN program launch skipped\n", .{});
            return;
        }

        var env = try buildUserEnv(allocator, ctx);
        defer env.deinit();

        var child = try std.process.spawn(io, .{
            .argv = argv,
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
            .uid = ctx.uid,
            .gid = ctx.gid,
            .cwd = .{ .path = ctx.home },
            .environ_map = &env,
        });
        const term = try child.wait(io);
        std.debug.print("program exit: {any}\n", .{term});
        return;
    }

    log.info("EXEC program: program={s}", .{program});
    if (args.len > 0) {
        log.info(" args=[", .{});
        for (args, 0..) |arg, i| {
            if (i > 0) log.info(", ", .{});
            log.info("{s}", .{arg});
        }
        log.info("]", .{});
    }
    log.info(" user=<current>\n", .{});

    if (dry_run_enabled) {
        log.info("DRY-RUN program launch skipped\n", .{});
        return;
    }

    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });
    const term = try child.wait(io);
    std.debug.print("program exit: {any}\n", .{term});
}

fn executeShellCommandAsUser(
    allocator: std.mem.Allocator,
    io: std.Io,
    shell_command: []const u8,
    detach: bool,
) !void {
    const maybe_user = try user_context.detectExecutionUser(allocator);
    defer if (maybe_user) |ctx| user_context.freeUserContext(allocator, ctx);

    if (maybe_user) |ctx| {
        log.info(
            "EXEC command: shell={s} detach={} user={s} uid={} gid={}\n",
            .{ shell_command, detach, ctx.username, ctx.uid, ctx.gid },
        );

        if (dry_run_enabled) {
            log.info("DRY-RUN command execution skipped\n", .{});
            return;
        }

        var env = try buildUserEnv(allocator, ctx);
        defer env.deinit();

        const argv: []const []const u8 = if (detach)
            &[_][]const u8{ "setsid", "/bin/sh", "-c", shell_command }
        else
            &[_][]const u8{ "/bin/sh", "-c", shell_command };

        var child = try std.process.spawn(io, .{
            .argv = argv,
            .stdin = .ignore,
            .stdout = .ignore,
            .stderr = .ignore,
            .uid = ctx.uid,
            .gid = ctx.gid,
            .cwd = .{ .path = ctx.home },
            .environ_map = &env,
        });

        if (detach) {
            return;
        }

        const term = try child.wait(io);
        std.debug.print("command exit: {any}\n", .{term});
        return;
    }

    log.info(
        "EXEC command: shell={s} detach={} user=<current>\n",
        .{ shell_command, detach },
    );

    if (dry_run_enabled) {
        log.info("DRY-RUN command execution skipped\n", .{});
        return;
    }

    const argv: []const []const u8 = if (detach)
        &[_][]const u8{ "setsid", "/bin/sh", "-c", shell_command }
    else
        &[_][]const u8{ "/bin/sh", "-c", shell_command };

    var child = try std.process.spawn(io, .{
        .argv = argv,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });

    if (detach) {
        return;
    }

    const term = try child.wait(io);
    std.debug.print("command exit: {any}\n", .{term});
}

fn buildArgv(
    allocator: std.mem.Allocator,
    program: []const u8,
    args: []const []const u8,
) ![][]const u8 {
    const argv = try allocator.alloc([]const u8, args.len + 1);
    argv[0] = program;
    for (args, 0..) |arg, i| {
        argv[i + 1] = arg;
    }
    return argv;
}

fn buildUserEnv(
    allocator: std.mem.Allocator,
    ctx: user_context.UserContext,
) !std.process.Environ.Map {
    var env = std.process.Environ.Map.init(allocator);

    try env.put("HOME", ctx.home);
    try env.put("USER", ctx.username);
    try env.put("LOGNAME", ctx.username);

    try copyEnvIfPresent(&env, "DISPLAY");
    try copyEnvIfPresent(&env, "WAYLAND_DISPLAY");
    try copyEnvIfPresent(&env, "XAUTHORITY");

    try copyEnvIfPresent(&env, "XDG_CURRENT_DESKTOP");
    try copyEnvIfPresent(&env, "DESKTOP_SESSION");
    try copyEnvIfPresent(&env, "XDG_SESSION_TYPE");
    try copyEnvIfPresent(&env, "XDG_SESSION_DESKTOP");

    try copyEnvIfPresent(&env, "LANG");
    try copyEnvIfPresent(&env, "LC_ALL");
    try copyEnvIfPresent(&env, "LC_CTYPE");
    try copyEnvIfPresent(&env, "LC_MESSAGES");

    try copyEnvIfPresent(&env, "SHELL");
    try copyEnvIfPresent(&env, "TERM");

    const runtime_dir = if (getEnv("XDG_RUNTIME_DIR")) |value|
        try allocator.dupe(u8, value)
    else
        try std.fmt.allocPrint(allocator, "/run/user/{}", .{ctx.uid});
    defer allocator.free(runtime_dir);

    try env.put("XDG_RUNTIME_DIR", runtime_dir);

    const dbus_addr = if (getEnv("DBUS_SESSION_BUS_ADDRESS")) |value|
        try allocator.dupe(u8, value)
    else
        try std.fmt.allocPrint(allocator, "unix:path={s}/bus", .{runtime_dir});
    defer allocator.free(dbus_addr);

    try env.put("DBUS_SESSION_BUS_ADDRESS", dbus_addr);

    return env;
}

fn copyEnvIfPresent(env: *std.process.Environ.Map, comptime key: [:0]const u8) !void {
    if (getEnv(key)) |value| {
        try env.put(key, value);
    }
}

fn getEnv(comptime key: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(key) orelse return null;
    return std.mem.span(value);
}
