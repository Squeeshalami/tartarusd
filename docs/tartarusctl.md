# `tartarusctl` Command Guide

`tartarusctl` is the CLI companion for `tartarusd`. It covers:

- locating and validating config,
- inspecting input devices,
- checking daemon state,
- sending reload signals,
- stopping daemon processes,
- debugging key mapping behavior.

## Quick Start

```bash
# Create default config if missing
tartarusctl init-config

# Validate config syntax and show active config path
tartarusctl validate

# Check overall health (config, devices, uinput, daemon)
tartarusctl status
```

## Command Syntax

```text
tartarusctl <command> [args...]
```

If no command is provided, `tartarusctl` prints usage.

Per-command help is available by appending `help`:

```bash
tartarusctl <command> help
```

If an unknown command is provided, it prints:

- `unknown command: <name>`
- the usage block

## Config Path Resolution

Commands that need config always resolve the default path internally:

`$HOME/.config/tartarusd/tartarus.toml`

If `SUDO_USER` is set and found in `/etc/passwd`, the CLI prefers that user's home directory over the current `HOME`.

This is why `tartarusctl` and `tartarusd` can behave sensibly when invoked via `sudo`.

## Command Reference

### `status`

Shows a structured runtime health report:

- config file availability at the resolved path
- Tartarus device detection and per-device node access
- `/dev/uinput` existence and read/write availability
- daemon state and matching PIDs (`pgrep tartarusd`)
- final pass/fail summary

```bash
tartarusctl status
```

Notes:

- Daemon detection uses `pgrep tartarusd`.
- Device detection uses Tartarus name matching from sysfs metadata.
- `/dev/uinput` access is checked by opening it read/write.

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

## Typical Workflows

### First-time setup

```bash
tartarusctl init-config
tartarusctl validate
tartarusctl status
```

### Validate and inspect a new mapping

```bash
tartarusctl validate
tartarusctl lookup base main_05
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

## Debug Commands (Not in Usage Output)

These commands are still available for low-level troubleshooting, but they are intentionally hidden from the default usage list:

- `tartarusctl inspect-device <event_path>` — prints detailed metadata for one event node.
- `tartarusctl monitor-device <event_path>` — streams raw input events from one event node.
