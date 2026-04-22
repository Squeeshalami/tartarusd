const std = @import("std");
const model = @import("common").model;

pub fn freeConfigModel(allocator: std.mem.Allocator, cfg: model.ConfigModel) void {
    allocator.free(cfg.default_layer);

    for (cfg.layers) |layer| {
        allocator.free(layer.name);

        for (layer.bindings) |binding| {
            allocator.free(binding.logical_key);

            switch (binding.action) {
                .key => |a| {
                    allocator.free(a.key);
                },
                .layer => |a| {
                    allocator.free(a.target);
                },
                .combo => |a| {
                    for (a.keys) |key| allocator.free(key);
                    allocator.free(a.keys);
                },
                .exec => |a| {
                    allocator.free(a.program);
                    for (a.args) |arg| allocator.free(arg);
                    allocator.free(a.args);
                },
                .command => |a| {
                    allocator.free(a.shell);
                },
            }
        }

        allocator.free(layer.bindings);
    }

    allocator.free(cfg.layers);
}
