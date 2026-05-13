const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const common_mod = b.createModule(.{
        .root_source_file = b.path("src/common/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const config_mod = b.createModule(.{
        .root_source_file = b.path("src/config/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    config_mod.addImport("common", common_mod);

    const device_mod = b.createModule(.{
        .root_source_file = b.path("src/device/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    device_mod.addImport("common", common_mod);

    const linux_mod = b.createModule(.{
        .root_source_file = b.path("src/linux/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    linux_mod.addImport("common", common_mod);
    linux_mod.addImport("device", device_mod);

    const daemon_support_mod = b.createModule(.{
        .root_source_file = b.path("src/daemon/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    daemon_support_mod.addImport("common", common_mod);
    daemon_support_mod.addImport("daemon_support", daemon_support_mod);
    daemon_support_mod.addImport("config", config_mod);
    daemon_support_mod.addImport("device", device_mod);
    daemon_support_mod.addImport("linux", linux_mod);

    const daemon_mod = b.createModule(.{
        .root_source_file = b.path("src/daemon/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    daemon_mod.addImport("common", common_mod);
    daemon_mod.addImport("config", config_mod);
    daemon_mod.addImport("daemon_support", daemon_support_mod);
    daemon_mod.addImport("device", device_mod);
    daemon_mod.addImport("linux", linux_mod);

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    cli_mod.addImport("common", common_mod);
    cli_mod.addImport("config", config_mod);
    cli_mod.addImport("daemon_support", daemon_support_mod);
    cli_mod.addImport("linux", linux_mod);

    const daemon = b.addExecutable(.{
        .name = "tartarusd",
        .root_module = daemon_mod,
    });

    const cli = b.addExecutable(.{
        .name = "tartarusctl",
        .root_module = cli_mod,
    });

    b.installArtifact(daemon);
    b.installArtifact(cli);

    const run_daemon = b.addRunArtifact(daemon);
    if (b.args) |args| {
        run_daemon.addArgs(args);
    }

    const run_cli = b.addRunArtifact(cli);
    if (b.args) |args| {
        run_cli.addArgs(args);
    }

    const run_daemon_step = b.step("run-daemon", "Run tartarusd");
    run_daemon_step.dependOn(&run_daemon.step);

    const run_cli_step = b.step("run-cli", "Run tartarusctl");
    run_cli_step.dependOn(&run_cli.step);
}
