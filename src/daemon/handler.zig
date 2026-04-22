const std = @import("std");
const model = @import("common").model;
const state_mod = @import("daemon_support").state;
const executor = @import("daemon_support").executor;

pub fn handleEvent(
    allocator: std.mem.Allocator,
    state: *state_mod.State,
    event: model.InputEvent,
) !void {
    const action = state.lookupActive(event.logical_key) orelse return error.NoBinding;

    switch (action) {
        .key => |a| {
            if (event.trigger == .repeat) return;

            var key_action = a;
            key_action.trigger = event.trigger;

            try executor.executeAction(allocator, .{
                .key = key_action,
            });
        },
        .combo => |a| {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, .{
                .combo = a,
            });
        },
        .exec => {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, action);
        },
        .command => {
            if (event.trigger != .press) return;
            try executor.executeAction(allocator, action);
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
                        .press => try state.setLayer(a.target),
                        .release => state.resetLayer(),
                        .repeat => return,
                    }
                },
            }
            try executor.executeAction(allocator, action);
        },
    }
}
