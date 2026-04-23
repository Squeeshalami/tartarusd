# `tartarusctl` Command Guide

`tartarusctl` is the CLI companion for `tartarusd`. It focuses on:

- locating and validating config,
- inspecting input devices,
- checking daemon state,
- sending reload signals,
- stopping daemon processes,
- debugging key mapping behavior.

This document reflects the current implementation in `src/cli`.

## Quick Start

```bash
# Show where the config file is expected
tartarusctl config-path

# Create default config if missing
tartarusctl init-config

# Validate config syntax and action schema
tartarusctl validate

# Check overall health (config, devices, uinput, daemon)
tartarusctl doctor
```

## Command Syntax

```text
tartarusctl <command> [args...]
```

If no command is provided, `tartarusctl` prints usage.

If an unknown command is provided, it prints:

- `unknown command: <name>`
- the usage block

## Config Path Resolution

Commands that need config always resolve the default path internally:

`$HOME/.config/tartarusd/tartarus.toml`

If `SUDO_USER` is set and found in `/etc/passwd`, the CLI prefers that user's home directory over the current `HOME`.

This is why `tartarusctl` and `tartarusd` can behave sensibly when invoked via `sudo`.

## Command Reference

### `config-path`

Prints the resolved config file path and exits.

```bash
tartarusctl config-path
```

Use this when scripts need the exact path used by the CLI.

---

### `status`

Shows high-level runtime state:

- CLI header (`tartarusctl status`)
- config path
- whether daemon process(es) are running (`pgrep tartarusd`)
- matching Tartarus event devices

```bash
tartarusctl status
```

Notes:

- Daemon detection uses `pgrep tartarusd`.
- Device detection uses Tartarus name matching from sysfs metadata.

---

### `validate`

Parses the config and reports either:

- `config OK: <path>`, or
- `config invalid: <path>` with parse details and optional hint.

```bash
tartarusctl validate
```

Example error diagnostics include:

- parse kind (e.g. `MissingSectionHeader`)
- concrete parser error name
- line number + raw line content (when available)
- hint text for common parse categories

This command is the fastest way to check if your `tartarus.toml` is loadable.

---

### `init-config`

Creates the config directory and writes a default config if missing.

```bash
tartarusctl init-config
```

Behavior:

- creates `~/.config/tartarusd` (or resolved equivalent),
- writes `tartarus.toml` only if it does not already exist,
- prints whether it created a new file or found an existing one.

---

### `lookup <layer> <logical-key>`

Resolves a single binding from the parsed config and prints the expanded action.

```bash
tartarusctl lookup base main_01
```

Output format:

```text
resolved binding: layer=<layer> key=<logical-key> -> <action-render>
```

If no binding exists for that exact pair:

```text
no binding found for layer=<layer> key=<logical-key>
```

`lookup` is literal; it does not simulate runtime fallback behavior here, it just queries the specific layer.

---

### `lookup-keycode <name>`

Translates a human key name to Linux keycode using internal keymap tables.

```bash
tartarusctl lookup-keycode enter
tartarusctl lookup-keycode leftctrl
tartarusctl lookup-keycode up
```

Success output:

```text
keycode: <name> -> <numeric-code>
```

Unknown names print:

```text
unknown key name: <name>
```

Use this before writing `key` or `combo` actions in config.

---

### `find-tartarus`

Finds event nodes that look like a Tartarus device and prints matching `/dev/input/event*` paths.

```bash
tartarusctl find-tartarus
```

Current matching logic checks sysfs device names for:

- `Razer Tartarus V2`, or
- `Razer Tartarus`

If none are found:

```text
no Tartarus event nodes found
```

---

### `list-input-devices`

Lists every event device under `/dev/input` and its human-readable name.

```bash
tartarusctl list-input-devices
```

Output format:

```text
input event devices:
  /dev/input/event0  ->  <name>
  ...
```

Useful when you need to choose an explicit node for `inspect-device` or `monitor-device`.

---

### `inspect-device <event_path>`

Prints detailed metadata for one event node:

- event path and event name (`eventX`)
- kernel device name
- resolved sysfs device path
- vendor and product ids (if available)

```bash
tartarusctl inspect-device /dev/input/event7
```

If the path is invalid or inaccessible, you get a descriptive failure line with the Zig error name.

---

### `monitor-device <event_path>`

Streams raw Linux input events from one event node, plus decoded Tartarus control ids when available.

```bash
tartarusctl monitor-device /dev/input/event7
```

Printed data includes:

- event timestamp (`sec`, `usec`)
- event type name (`EV_KEY`, etc.)
- code and value
- interpreted value (`press`, `release`, `repeat`, etc.)
- decoded Tartarus `control_id` / `trigger`
- mapped `logical_key` if known

Stop with `Ctrl+C`.

This is the most useful command when authoring or debugging bindings.

---

### `reload`

Sends `SIGHUP` to running `tartarusd` processes so they reload config.

```bash
tartarusctl reload
```

Behavior:

- finds daemon PIDs via `pgrep tartarusd`,
- sends `SIGHUP` to each PID,
- reports success with the PID list.

If no daemon is running, it prints:

```text
tartarusd is not running
```

If signaling fails with permission errors, it suggests running with `sudo`.

---

### `quit`

Sends `SIGTERM` to running `tartarusd` processes so they stop.

```bash
tartarusctl quit
```

Behavior:

- finds daemon PIDs via `pgrep tartarusd`,
- sends `SIGTERM` to each PID,
- reports success with the PID list.

If no daemon is running, it prints:

```text
tartarusd is not running
```

If signaling fails with permission errors, it suggests running with `sudo`.

---

### `doctor`

Runs an environment checklist and prints `[OK]` / `[FAIL]` lines.

```bash
tartarusctl doctor
```

Checks include:

- config file exists at resolved path,
- Tartarus devices found and each path is readable,
- `/dev/uinput` exists,
- `/dev/uinput` is readable/writable,
- daemon running (`pgrep tartarusd`).

`doctor` is the best first step when the daemon is not behaving as expected.

## Typical Workflows

### First-time setup

```bash
tartarusctl init-config
tartarusctl validate
tartarusctl doctor
```

### Validate and inspect a new mapping

```bash
tartarusctl lookup-keycode leftctrl
tartarusctl validate
tartarusctl lookup base main_05
```

### Hardware troubleshooting

```bash
tartarusctl list-input-devices
tartarusctl find-tartarus
tartarusctl inspect-device /dev/input/event7
tartarusctl monitor-device /dev/input/event7
```

### Reload live daemon config

```bash
tartarusctl validate
tartarusctl reload
tartarusctl status
```

### Stop daemon

```bash
tartarusctl status
tartarusctl quit
tartarusctl status
```

## Notes and Limitations

- `tartarusctl` currently has no global flags (for example, no `--help`/`--verbose` handler in `main`).
- `reload` assumes process name matching via `pgrep tartarusd`.
- `quit` assumes process name matching via `pgrep tartarusd`.
- Device matching for Tartarus is name-based from sysfs metadata.
- Most command failures are reported as user-facing text lines; some lower-level errors can still bubble up as process errors.
