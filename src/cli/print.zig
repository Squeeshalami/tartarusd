const std = @import("std");
const model = @import("common").model;

pub fn printConfigSummary(cfg: model.ConfigModel) void {
    std.debug.print("default layer: {s}\n", .{cfg.default_layer});
    std.debug.print("layer count: {}\n", .{cfg.layers.len});

    for (cfg.layers) |layer| {
        std.debug.print("  layer {s}: {} bindings\n", .{
            layer.name,
            layer.bindings.len,
        });
    }
}

pub fn printConfigBindings(cfg: model.ConfigModel) void {
    std.debug.print("default layer: {s}\n", .{cfg.default_layer});

    for (cfg.layers) |layer| {
        std.debug.print("\n[layer {s}]\n", .{layer.name});

        for (layer.bindings) |binding| {
            std.debug.print("  {s} -> ", .{binding.logical_key});
            printAction(binding.action);
            std.debug.print("\n", .{});
        }
    }
}

pub fn printAction(action: model.Action) void {
    switch (action) {
        .key => |a| {
            std.debug.print("key({s}, trigger={s})", .{
                a.key,
                @tagName(a.trigger),
            });
        },
        .combo => |a| {
            std.debug.print("combo(", .{});
            for (a.keys, 0..) |key, i| {
                if (i > 0) std.debug.print("+", .{});
                std.debug.print("{s}", .{key});
            }
            std.debug.print(", trigger={s})", .{
                @tagName(a.trigger),
            });
        },
        .exec => |a| {
            std.debug.print("exec(program={s}", .{a.program});
            if (a.args.len > 0) {
                std.debug.print(", args=[", .{});
                for (a.args, 0..) |arg, i| {
                    if (i > 0) std.debug.print(", ", .{});
                    std.debug.print("{s}", .{arg});
                }
                std.debug.print("]", .{});
            }
            std.debug.print(")", .{});
        },
        .command => |a| {
            std.debug.print("command(shell={s}, detach={}, cooldown_ms={})", .{
                a.shell,
                a.detach,
                a.cooldown_ms,
            });
        },
        .layer => |a| {
            std.debug.print("layer(target={s}, mode={s})", .{
                a.target,
                @tagName(a.mode),
            });
        },
    }
}
