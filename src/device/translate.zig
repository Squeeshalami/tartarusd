const model = @import("common").model;
const profile = @import("profile.zig");

pub fn translatePhysicalEvent(event: model.PhysicalInputEvent) ?model.InputEvent {
    const logical_key = profile.mapControlToLogicalKey(event.control_id) orelse return null;

    return .{
        .logical_key = logical_key,
        .trigger = event.trigger,
    };
}
