# Configuring `tartarus.toml`

This document describes how to write a valid configuration for **tartarusd**: where the file lives, what structure the parser expects, and every option available in bindings. The annotated example at `examples/tartarus.toml` covers the same content and is a useful starting point.

## Where the file goes

The daemon and CLI look for:

`$HOME/.config/tartarusd/tartarus.toml`

If `sudo` is used to invoke a command, the tools prefer the home directory of `SUDO_USER` when that variable is set, so config paths remain tied to the original user's account rather than root's.

## Creating a starting file

```bash
tartarusctl init-config
```

This creates the config directory and, if the file is missing, writes a default config. The generated file has the same content as `examples/tartarus.toml`.

Check that a file parses:

```bash
tartarusctl validate
```

## Important: this is not a full TOML implementation

The loader is a **line-oriented** parser. It understands:

- line comments that start with `#` (after leading spaces),
- a top-level `default_layer = "…"` assignment,
- layer sections declared as `[layer.<name>]` (for example `[layer.base]`),
- **binding** lines of the form `logical_key = { type = "…", … }`.

String values in binding objects must be wrapped in **double quotes**. Array fields use square brackets and comma‑separated quoted strings, e.g. `["ctrl", "shift"]`. Inside the `{ … }` object, fields are separated by **commas** (the parser tracks brackets so commas inside `[]` do not break parsing).

A line containing only `[device]` or `[global]` (or any other `[…]` header that is **not** `[layer.…]`) is treated as a **section marker only**: the parser does not read key–value settings from those blocks yet (see [Device and global metadata](#device-and-global-metadata)).

## Required top-level content

1. **`default_layer`**  
   A line of the form:

   ```text
   default_layer = "base"
   ```

   The value must be a **quoted** layer name. That layer must be defined in a `[layer.…]` section. You can place this line before or after layer sections; convention is to keep it under `[global]` in examples.

2. **At least one layer**  
   A section header like `[layer.base]` followed by zero or more binding lines. (An empty layer is valid but not useful.)

## Device and global metadata

Put `default_layer` under `[global]`. `tartarusctl init-config` copies `src/config/template.zig`, which may include a `[device]` header and sample lines underneath; **nothing in a `[device]` block is parsed** for behavior, so you can delete that section or leave it as a visual divider.

```toml
[global]
default_layer = "base"
```

**Current behavior:**

| Key / line        | Purpose |
| ----------------- | -------- |
| `[device]`        | Optional. **Not parsed** for any settings. |
| `grab_device`     | **Not read** from the file. In **live** mode the daemon always attempts to **grab** the evdev device (exclusive access). |
| `[global]`        | Conventional place for `default_layer` and notes. |
| `log_level`       | **Not read** from the file. Use `tartarusd --verbose` (or your service wrapper) for extra logging. |

By default the daemon auto-detects an evdev device whose name contains both `razer` and `tartarus` (see `tartarusctl find-tartarus`). To use a specific node instead:

```text
tartarusd --device /dev/input/event7
```

## Layer sections

**Syntax:** `[layer.<layer_name>]` on its own line, with no spaces inside the angle brackets. Example:

```text
[layer.base]
[layer.nav]
```

**Rules:**

- Every `default_layer` value must match some `[layer.…]` name.
- Layer names are **case-sensitive** (`Base` and `base` are different).
- When a new `[layer.…]` or a non-layer `[…]` line appears, the previous layer’s bindings are **closed** and stored.

## Bindings: left-hand side (logical key)

Each binding line looks like:

```text
<logical_key> = { type = "…", … }
```

`logical_key` is the name the daemon uses after translating raw input from the Tartarus. It must match the **stable names** in the table below (these are the same strings shown when you follow physical events in verbose logs).

### Tartarus V2 logical key names

| Physical region | Logical key names |
| --------------- | ----------------- |
| Main grid (5×4) | `main_01` … `main_20` (row-major: `main_01`–`main_05` first row, etc.) |
| D-pad | `dpad_up`, `dpad_left`, `dpad_right`, `dpad_down` |
| Thumb | `thumb_button_1` |

Key names can be confirmed by monitoring raw device events with `tartarusctl monitor-device` while pressing buttons on the Tartarus.

**Lookup helper:**

```bash
tartarusctl lookup <layer> <logical_key>
```

## Bindings: right-hand side (actions)

The right-hand side is always a braced object with a **`type`** field. Supported types: `key`, `combo`, `exec`, `command`, `layer`.

### `key` — emit a single key

```text
main_01 = { type = "key", key = "1" }
```

| Field  | Required | Description |
| ------ | -------- | ----------- |
| `key`  | yes      | A **key name** recognized by the internal map (Linux keycodes). Examples: `1`, `a`, `enter`, `up`, `leftctrl`. |

**Runtime:** Press and release follow the physical event; autorepeat from the device is ignored for `key` actions.

### `combo` — chord (modifiers + key) in one shot

```text
main_02 = { type = "combo", keys = ["ctrl", "shift", "p"] }
```

| Field  | Required | Description |
| ------ | -------- | ----------- |
| `keys` | yes      | Non-empty array of key names, e.g. modifier names plus a letter. |

**Runtime:** Only fires on **press** (release does not decompose the combo).

### `exec` — run a program without a shell

```text
main_03 = { type = "exec", program = "ghostty", args = [] }
```

| Field     | Required | Description |
| --------- | -------- | ----------- |
| `program` | yes      | Path or executable name resolved like `execve` (first segment is the binary). |
| `args`    | no       | Array of extra arguments. If omitted, it defaults to an empty list (`[]`). |

**Runtime:** Only on **press**. The daemon spawns the child process under the user identified by `SUDO_USER` when set (i.e. the user who invoked sudo), otherwise under the user running the daemon. Check runtime logs if a launched program is not running under the expected user.

### `command` — run a string via `/bin/sh -c`

```text
main_04 = { type = "command", shell = "playerctl play-pause", detach = true }
```

| Field     | Required | Default | Description |
| --------- | -------- | ------- | ----------- |
| `shell`   | yes      | —       | Full shell command string. |
| `detach`  | no       | `true`  | If `true`, the shell command is **spawned** and not waited on; if `false`, the process is waited for. |

`cooldown_ms` exists in the internal model for future use; it is **not** set from the config file today (parsed command actions use `0`).

**Runtime:** Only on **press**.

### `layer` — change the active layer

```text
main_05 = { type = "layer", target = "nav", mode = "hold" }
```

| Field    | Required | Description |
| -------- | -------- | ----------- |
| `target` | yes      | Name of a layer (must match a `[layer.…]` section). |
| `mode`   | yes      | `set`, `hold`, or `toggle` (see below). |

**Modes:**

| Mode     | Behavior |
| -------- | -------- |
| `set`    | On **press**, switch the active layer to `target`. |
| `hold`   | On **press**, switch to `target`; on **release**, restore the default layer. |
| `toggle` | On **press**, switch between `target` and the configured **default** layer. |

`target` must exist; unknown layers are errors at runtime.

**Note:** The handler also invokes logging/simulation for the layer action in current builds; layer switching in state still applies as described.

## How bindings are chosen at runtime

For each input event, the daemon resolves:

1. The binding on the **active** layer, if any.
2. If none, and the active layer is **not** the `default_layer`, the binding on the **default** layer (fallback).

If no binding is found, the event is effectively ignored (no action).

## Troubleshooting and validation

- **`tartarusctl validate`** — Parses the config and reports line-level errors.
- **Parse error hints** (from the CLI) point to common fixes: `MissingSectionHeader` (put lines under `[layer.…]`), `UnknownActionType` (use one of the five types), `InvalidLayerMode`, invalid arrays (strings must be quoted in `[]`).

Typical mistakes:

- Missing `default_layer` or unquoted `default_layer`.
- Using a `default_layer` name with no matching `[layer.name]`.
- Typos in `type` or `mode` string values.
- Binding lines outside any `[layer.…]` block (or before the first layer header) — the parser will error with `MissingSectionHeader` for lines with `=` that are not `default_layer`.

## See also

- `examples/tartarus.toml` — full annotated copy of the default layout and sample bindings.
- `tartarusctl status` — environment checks (config file presence, device nodes + access, `/dev/uinput`, daemon process).

Reloading the daemon’s config: **`tartarusctl reload`** sends **SIGHUP** to running `tartarusd` processes; the live event loop then reloads the file from the default config path.
