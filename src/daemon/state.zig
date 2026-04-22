const std = @import("std");
const model = @import("common").model;
const mapper = @import("daemon_support").mapper;

pub const State = struct {
    cfg: model.ConfigModel,
    active_layer: []const u8,

    pub fn init(cfg: model.ConfigModel) State {
        return .{
            .cfg = cfg,
            .active_layer = cfg.default_layer,
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
};
