# tartarusd

`tartarusd` is a Linux userspace remapping daemon and CLI for the **Razer Tartarus V2**, written in **Zig**.

This project exists mainly as a **learning exercise** in Linux systems programming, device handling, and daemon design. So a few Disclaimers before you continue:
1. Most people do not own a Tartarus, if this is you, this probably won't be useful.
2. Even among people who do, most will be better served by existing general-purpose tools.
3. I am in no way claiming this is well written Zig code, so use with caution. 

It is not trying to be a mass-market remapping app. The point here is to learn by building a small, real systems tool with:

- `evdev` input reading
- `uinput` output injection
- `udev`-based non-root access
- a long-running daemon
- a config file driven remapping model
- a small CLI for debugging and control

Even so, it is functional and usable if you happen to own a **Razer Tartarus V2** and want a file-based remapper.

---

## What it does

`tartarusd`:

- detects Razer Tartarus-related input event nodes
- reads real hardware input from the device
- translates physical controls into stable logical control names
- resolves actions through a layer-based config
- injects keyboard output through `uinput`
- runs commands or programs from bindings
- supports config reload without restarting the daemon

`tartarusctl` provides utilities for:

- checking status
- validating config
- reloading the daemon
- stopping the daemon
- listing devices
- optional low-level device inspection/debugging
- running an environment health/status check

---

## Current action support

The current focus is on these action types:

- `key`
- `combo`
- `exec`
- `command`
- `layer`

Examples:

- map a Tartarus button to a single key
- map a button to a combo like `ctrl+shift+p`
- launch a program like `ghostty`
- run a shell command like `playerctl play-pause`
- switch or hold a layer
- bind the scroll wheel to logical controls like `scroll_up` and `scroll_down`

---

## Current project status

This is still an early version, but it already supports:

- real live device handling
- multi-node Tartarus discovery
- non-root operation through `udev` rules
- hot config reload
- wheel event translation
- a cleaned-up CLI with practical commands

This is **not** trying to be polished desktop software. It is a small Linux systems project that happens to be useful.

---

## Why this exists

This project is mostly about learning:

- how Linux input devices work
- how to work with `evdev` and `uinput`
- how daemons and CLIs fit together
- how to structure a config-driven systems tool in Zig

If you are looking at this repo wondering “who is this for?”, the answer is mostly:

- me

But...

- anyone curious about Linux input tooling
- anyone who likes odd little hardware/software projects

Might find it useful or interesting!

---

## Requirements

- Linux
- Zig
- a **Razer Tartarus V2**
- access to:
  - `/dev/input/event*`
  - `/dev/uinput`

The project is designed to run **without `sudo`** once the correct `udev` permissions are set up.

---

## Documentation

You can find some setup and getting started information here.

- **[Permissions](docs/permissions.md)** — `udev` rules, the `tartarusd` group, and running without `sudo`
- **[Configuration](docs/configuration.md)** — `tartarus.toml`: paths, layers, bindings, and action types
- **[tartarusctl](docs/tartarusctl.md)** — CLI commands, device inspection, status checks, and debugging

---

## Building

From the repo root:

```bash
zig build
```

In ./zig-out/bin you will find the binaries, you can move those to any folder in PATH (I use ~/.local/bin) and run them by name.

```bash
tartarusd # to in terminal

tartarusd & # run in the background

tartarusctl # CLI tooling
```


