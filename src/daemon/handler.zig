const std = @import("std");
const model = @import("common").model;
const state_mod = @import("daemon_support").state;
const executor = @import("daemon_support").executor;

pub fn handleEvent(
    allocator: std.mem.Allocator,
    io: std.Io,
    state: *state_mod.State,
    event: model.InputEvent,
) !void {
    if (event.trigger == .release and state.endLayerHold(event.logical_key)) {
        return;
    }

    // If this key is configured as a hold-layer key on default layer, always
    // prioritize release-to-default behavior over active-layer remaps.
    if (event.trigger == .release) {
        if (state.lookupDefault(event.logical_key)) |default_action| {
            switch (default_action) {
                .layer => |a| {
                    if (a.mode == .hold) {
                        state.resetLayer();
                        return;
                    }
                },
                else => {},
            }
        }
    }

    const action = state.lookupActive(event.logical_key) orelse return error.NoBinding;

    switch (action) {
        .key => |a| {
            if (event.trigger == .repeat) return;

            var key_action = a;
            key_action.trigger = event.trigger;

            try executor.executeAction(allocator, io, .{
                .key = key_action,
            });
        },
        .combo => |a| {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, io, .{
                .combo = a,
            });
        },
        .exec => {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, io, action);
        },
        .command => {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, io, action);
        },
        .layer => |a| {
            switch (a.mode) {
                .set => {
                    if (event.trigger != .press) return;
                    try state.setLayer(a.target);
                },
                .toggle => {
                    if (event.trigger != .press) return;
                    try state.toggleLayer(a.target);
                },
                .hold => {
                    switch (event.trigger) {
                        .press => try state.beginLayerHold(event.logical_key, a.target),
                        .release => _ = state.endLayerHold(event.logical_key),
                        .repeat => return,
                    }
                },
            }
            try executor.executeAction(allocator, io, action);
        },
    }
}
