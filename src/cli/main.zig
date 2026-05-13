const std = @import("std");
const AppNames = @import("common").types.AppNames;
const config = @import("config");
const print = @import("print.zig");
const mapper = @import("daemon_support").mapper;
const linux = @import("linux");
const daemon_control = @import("daemon_control.zig");
const commands = @import("commands.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        commands.printUsage();
        return;
    }

    const cmd = args[1];
    const config_path = try config.path.getDefaultConfigPath(allocator);
    defer allocator.free(config_path);

    if (std.mem.eql(u8, cmd, "config-path")) return commands.handleConfigPath(config_path);
    if (std.mem.eql(u8, cmd, "status")) return try commands.handleStatus(allocator, init.io, config_path);
    if (std.mem.eql(u8, cmd, "validate")) return try commands.handleValidate(allocator, config_path);
    if (std.mem.eql(u8, cmd, "init-config")) return try commands.handleInitConfig(allocator, config_path);
    if (std.mem.eql(u8, cmd, "lookup")) return try commands.handleLookup(allocator, config_path, args);
    if (std.mem.eql(u8, cmd, "list-input-devices")) return try commands.handleListInputDevices(allocator);
    if (std.mem.eql(u8, cmd, "inspect-device")) return try commands.handleInspectDevice(allocator, args);
    if (std.mem.eql(u8, cmd, "monitor-device")) return try commands.handleMonitorDevice(args);
    if (std.mem.eql(u8, cmd, "find-tartarus")) return try commands.handleFindTartarus(allocator);
    if (std.mem.eql(u8, cmd, "lookup-keycode")) return commands.handleLookupKeycode(args);
    if (std.mem.eql(u8, cmd, "reload")) return try commands.handleReload(allocator, init.io);
    if (std.mem.eql(u8, cmd, "quit")) return try commands.handleQuit(allocator, init.io);
    if (std.mem.eql(u8, cmd, "doctor")) return try commands.handleDoctor(allocator, init.io, config_path);
    std.debug.print("unknown command: {s}\n\n", .{cmd});
    commands.printUsage();
}
