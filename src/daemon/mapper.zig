const std = @import("std");
const model = @import("common").model;

pub fn findLayer(cfg: model.ConfigModel, layer_name: []const u8) ?model.Layer {
    for (cfg.layers) |layer| {
        if (std.mem.eql(u8, layer.name, layer_name)) {
            return layer;
        }
    }
    return null;
}

pub fn findBinding(layer: model.Layer, logical_key: []const u8) ?model.Binding {
    for (layer.bindings) |binding| {
        if (std.mem.eql(u8, binding.logical_key, logical_key)) {
            return binding;
        }
    }
    return null;
}

pub fn lookupAction(
    cfg: model.ConfigModel,
    layer_name: []const u8,
    logical_key: []const u8,
) ?model.Action {
    const layer = findLayer(cfg, layer_name) orelse return null;
    const binding = findBinding(layer, logical_key) orelse return null;
    return binding.action;
}
