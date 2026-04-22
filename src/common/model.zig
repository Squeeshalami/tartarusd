const std = @import("std");

pub const Trigger = enum {
    press,
    release,
    repeat,
};

pub const LayerMode = enum {
    set,
    hold,
    toggle,
};

pub const KeyAction = struct {
    key: []const u8,
    trigger: Trigger = .press,
};

pub const ComboAction = struct {
    keys: []const []const u8,
    trigger: Trigger = .press,
};

pub const ExecAction = struct {
    program: []const u8,
    args: []const []const u8,
};

pub const CommandAction = struct {
    shell: []const u8,
    detach: bool = false,
    cooldown_ms: u32 = 0,
};

pub const LayerAction = struct {
    target: []const u8,
    mode: LayerMode,
};

pub const Action = union(enum) {
    key: KeyAction,
    combo: ComboAction,
    exec: ExecAction,
    command: CommandAction,
    layer: LayerAction,
};

pub const Binding = struct {
    logical_key: []const u8,
    action: Action,
};

pub const Layer = struct {
    name: []const u8,
    bindings: []const Binding,
};

pub const ConfigModel = struct {
    default_layer: []const u8,
    layers: []const Layer,
};

pub const PhysicalInputEvent = struct {
    control_id: []const u8,
    trigger: Trigger,
};

pub const InputEvent = struct {
    logical_key: []const u8,
    trigger: Trigger,
};
