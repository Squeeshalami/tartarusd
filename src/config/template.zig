pub const default_config =
    \\[global]
    \\default_layer = "base"
    \\
    \\[layer.base]
    \\main_01 = { type = "command", shell = "echo main_01 pressed" }
    \\main_02 = { type = "exec", program = "echo", args = ["main_02 pressed"] }
    \\main_03 = { type = "key", key = "left" }
    \\main_04 = { type = "combo", keys = ["ctrl", "shift", "p"] }
    \\main_05 = { type = "combo", keys = ["ctrl", "alt", "delete"] }
    \\
    \\main_20 = { type = "exec", program = "date", args = [] }
    \\
    \\dpad_up = { type = "key", key = "up" }
    \\dpad_left = { type = "key", key = "left" }
    \\dpad_right = { type = "key", key = "right" }
    \\dpad_down = { type = "key", key = "down" }
    \\thumb_button_1 = { type = "layer", target = "alt", mode = "hold" }
    \\scroll_up = { type = "command", shell = "echo scroll up" }
    \\scroll_down = { type = "command", shell = "echo scroll down" }
    \\
    \\[layer.alt]
    \\main_01 = { type = "command", shell = "echo alt layer command example" }
    \\main_02 = { type = "key", key = "left" }
    \\main_03 = { type = "key", key = "down" }
    \\main_04 = { type = "key", key = "right" }
    \\
    \\dpad_up = { type = "key", key = "up" }
    \\dpad_left = { type = "key", key = "left" }
    \\dpad_right = { type = "key", key = "right" }
    \\dpad_down = { type = "key", key = "down" }
    \\thumb_button_1 = { type = "key", key = "enter" }
;
