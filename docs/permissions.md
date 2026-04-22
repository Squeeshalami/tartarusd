# tartarusd setup without sudo

This guide sets up `tartarusd` so it can run as a normal user, without `sudo`, by granting access to:

* the Razer Tartarus input device under `/dev/input/event*`
* `/dev/uinput` for virtual keyboard injection

The approach uses:

* a dedicated Unix group named `tartarusd`
* udev rules for device permissions
* group membership for the user who will run the daemon

## Why this is needed

`tartarusd` needs two kinds of device access:

1. **Read and grab the Tartarus input device** via evdev.
2. **Create and write to a virtual keyboard** via `/dev/uinput`.

By default, both usually require elevated privileges. Instead of running the app with `sudo`, this setup grants access only to the devices and users you choose.

## 1. Create the `tartarusd` group

Run:

```bash
sudo groupadd --system tartarusd
```

If the group already exists, that is fine.

## 2. Add your user to the group

Run:

```bash
sudo usermod -aG tartarusd "$USER"
```

After doing this, **log out and log back in** so your session picks up the new group membership.

You can verify it later with:

```bash
groups
```

You should see `tartarusd` listed.

## 3. Create a udev rule for `/dev/uinput`

Create this file:

```text
/etc/udev/rules.d/80-tartarusd-uinput.rules
```

Put this in it:

```udev
KERNEL=="uinput", GROUP="tartarusd", MODE="0660"
```

This gives members of the `tartarusd` group read/write access to `/dev/uinput`.

## 4. Create a udev rule for the Tartarus input device

Your Tartarus vendor/product IDs are:

* vendor: `1532`
* product: `022b`

Create this file:

```text
/etc/udev/rules.d/81-tartarusd-input.rules
```

Put this in it:

```udev
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="022b", GROUP="tartarusd", MODE="0660"
```

This grants the `tartarusd` group access only to the matching Razer Tartarus input device nodes.

## 5. Reload udev rules

Run:

```bash
sudo udevadm control --reload
sudo udevadm trigger
```

## 6. Make sure the `uinput` module is loaded

Run:

```bash
sudo modprobe uinput
```

To verify:

```bash
lsmod | grep uinput
```

If you want `uinput` available automatically at boot, create:

```text
/etc/modules-load.d/uinput.conf
```

with:

```text
uinput
```

## 7. Verify device permissions

Check:

```bash
ls -l /dev/uinput
ls -l /dev/input/event7
```

Replace `/dev/input/event7` if your Tartarus ends up on a different event node.

What you want to see:

* group should be `tartarusd`
* group permissions should include `rw`

Example target shape:

```text
crw-rw---- 1 root tartarusd ... /dev/uinput
crw-rw---- 1 root tartarusd ... /dev/input/event7
```

## 8. Re-log if needed

If permissions look right but the daemon still cannot open the devices, log out and log back in again to ensure your session has the updated group membership.

## 9. Test without sudo

From the repo root, try:

```bash
zig build run-daemon
```

And in another terminal:

```bash
zig build run-cli -- status
```

If everything is set up correctly, `tartarusd` should:

* start without `sudo`
* find the Tartarus event node
* grab the device
* create the virtual keyboard through `/dev/uinput`

## 10. If the Tartarus node is not obvious

Use:

```bash
zig build run-cli -- list-input-devices
zig build run-cli -- find-tartarus
zig build run-cli -- inspect-device /dev/input/event7
```

And for deeper hardware attribute inspection:

```bash
udevadm info -a -n /dev/input/event7
```

This is useful if you ever want to refine the udev rule further.

## Troubleshooting

### `IoctlGrabFailed`

Most common cause: another `tartarusd` instance is already running.

Check with:

```bash
zig build run-cli -- status
```

Or:

```bash
pgrep -a tartarusd
```

### Permission denied on `/dev/uinput`

Check:

```bash
ls -l /dev/uinput
groups
```

Make sure:

* `/dev/uinput` is group-owned by `tartarusd`
* your user is in the `tartarusd` group
* you logged out and back in after adding the group

### Permission denied on `/dev/input/event*`

Check the Tartarus event node permissions:

```bash
ls -l /dev/input/event7
```

Make sure the matching udev rule applied and the device node has group `tartarusd`.

### `uinput` does not exist

Load it manually:

```bash
sudo modprobe uinput
```

Then re-check:

```bash
ls -l /dev/uinput
```

## Recommended next step

Once non-root launching works, the next quality-of-life improvement is to run `tartarusd` as a user service so it starts automa
