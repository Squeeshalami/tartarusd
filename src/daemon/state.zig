const std = @import("std");
const model = @import("common").model;
const mapper = @import("daemon_support").mapper;

const max_held_layers = 16;

const HeldLayer = struct {
    logical_key: []const u8,
    previous_layer: []const u8,
};

pub const State = struct {
    cfg: model.ConfigModel,
    active_layer: []const u8,
    held_layers: [max_held_layers]HeldLayer,
    held_layer_count: usize,

    pub fn init(cfg: model.ConfigModel) State {
        return .{
            .cfg = cfg,
            .active_layer = cfg.default_layer,
            .held_layers = undefined,
            .held_layer_count = 0,
        };
    }

    pub fn setLayer(self: *State, layer_name: []const u8) !void {
        const layer = mapper.findLayer(self.cfg, layer_name) orelse {
            return error.UnknownLayer;
        };
        self.active_layer = layer.name;
    }

    pub fn toggleLayer(self: *State, target_layer: []const u8) !void {
        _ = mapper.findLayer(self.cfg, target_layer) orelse {
            return error.UnknownLayer;
        };

        if (std.mem.eql(u8, self.active_layer, target_layer)) {
            self.active_layer = self.cfg.default_layer;
        } else {
            self.active_layer = target_layer;
        }
    }

    pub fn resetLayer(self: *State) void {
        self.active_layer = self.cfg.default_layer;
    }

    pub fn beginLayerHold(self: *State, logical_key: []const u8, target_layer: []const u8) !void {
        const layer = mapper.findLayer(self.cfg, target_layer) orelse {
            return error.UnknownLayer;
        };

        for (0..self.held_layer_count) |idx| {
            if (std.mem.eql(u8, self.held_layers[idx].logical_key, logical_key)) {
                return;
            }
        }

        if (self.held_layer_count >= max_held_layers) {
            return error.TooManyHeldLayers;
        }

        self.held_layers[self.held_layer_count] = .{
            .logical_key = logical_key,
            .previous_layer = self.active_layer,
        };
        self.held_layer_count += 1;
        self.active_layer = layer.name;
    }

    pub fn endLayerHold(self: *State, logical_key: []const u8) bool {
        var found_index: ?usize = null;
        var i = self.held_layer_count;
        while (i > 0) {
            i -= 1;
            if (std.mem.eql(u8, self.held_layers[i].logical_key, logical_key)) {
                found_index = i;
                break;
            }
        }

        const idx = found_index orelse return false;
        const previous_layer = self.held_layers[idx].previous_layer;

        var shift = idx;
        while (shift + 1 < self.held_layer_count) : (shift += 1) {
            self.held_layers[shift] = self.held_layers[shift + 1];
        }
        self.held_layer_count -= 1;
        self.active_layer = previous_layer;
        return true;
    }

    pub fn lookupActive(self: *const State, logical_key: []const u8) ?model.Action {
        if (mapper.lookupAction(self.cfg, self.active_layer, logical_key)) |action| {
            return action;
        }

        if (!std.mem.eql(u8, self.active_layer, self.cfg.default_layer)) {
            if (mapper.lookupAction(self.cfg, self.cfg.default_layer, logical_key)) |action| {
                return action;
            }
        }

        return null;
    }

    pub fn lookupDefault(self: *const State, logical_key: []const u8) ?model.Action {
        return mapper.lookupAction(self.cfg, self.cfg.default_layer, logical_key);
    }
};
