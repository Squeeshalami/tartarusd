# Setting up `tartarusd` without sudo

This guide sets up `tartarusd` so it can run as a normal user, without `sudo`, by granting access to:

* the Tartarus input device under `/dev/input/event*`
* `/dev/uinput` for virtual keyboard injection

The approach uses:

* a dedicated Unix group named `tartarusd`
* udev rules for device permissions
* group membership for the user who will run the daemon

## Why this is needed

`tartarusd` needs two kinds of device access:

1. **Read and grab the Tartarus input device** via evdev.
2. **Create and write to a virtual keyboard** via `/dev/uinput`.

By default, both usually require elevated privileges. Instead of running the daemon with `sudo`, this setup grants access only to the devices and users you choose.

## 1. Create the `tartarusd` group

```bash
sudo groupadd --system tartarusd
```

If the group already exists, that is fine.

## 2. Add your user to the group

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

## 4. Find your device vendor and product IDs

Before writing the input device udev rule, you need to find the vendor and product IDs for your specific Tartarus model. Run:

```bash
tartarusctl find-tartarus
```

Then inspect the device node it reports (replacing `eventX` with the actual number):

```bash
tartarusctl inspect-device /dev/input/eventX
```

This prints the vendor and product IDs. Alternatively, use `udevadm`:

```bash
udevadm info -a -n /dev/input/eventX | grep -E 'idVendor|idProduct'
```

For reference, the Razer Tartarus V2 uses vendor `1532` and product `022b`. Other Tartarus models may use different product IDs.

## 5. Create a udev rule for the Tartarus input device

Once you have the vendor and product IDs, create this file:

```text
/etc/udev/rules.d/81-tartarusd-input.rules
```

Put this in it, substituting your actual IDs:

```udev
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="<vendor_id>", ATTRS{idProduct}=="<product_id>", GROUP="tartarusd", MODE="0660"
```

For example, for the Razer Tartarus V2:

```udev
SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="022b", GROUP="tartarusd", MODE="0660"
```

This grants the `tartarusd` group access only to the matching Tartarus input device nodes.

## 6. Reload udev rules

```bash
sudo udevadm control --reload
sudo udevadm trigger
```

## 7. Make sure the `uinput` module is loaded

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

## 8. Verify device permissions

First find the event node for your Tartarus:

```bash
tartarusctl find-tartarus
```

Then check the permissions on that node and on `/dev/uinput`:

```bash
ls -l /dev/uinput
ls -l /dev/input/eventX   # replace eventX with your actual node
```

What you want to see:

* group should be `tartarusd`
* group permissions should include `rw`

Example target shape:

```text
crw-rw---- 1 root tartarusd ... /dev/uinput
crw-rw---- 1 root tartarusd ... /dev/input/eventX
```

## 9. Re-log if needed

If permissions look right but the daemon still cannot open the devices, log out and log back in again to ensure your session has the updated group membership.

## 10. Test without sudo

Start the daemon:

```bash
tartarusd
```

In another terminal, check its status:

```bash
tartarusctl status
```

If everything is set up correctly, `tartarusd` should:

* start without `sudo`
* find the Tartarus event node
* grab the device
* create the virtual keyboard through `/dev/uinput`

## 11. If the Tartarus node is not obvious

```bash
tartarusctl find-tartarus
tartarusctl inspect-device /dev/input/eventX
```

And for deeper hardware attribute inspection:

```bash
udevadm info -a -n /dev/input/eventX
```

This is useful if you need to refine the udev rule or confirm device attributes.

## Troubleshooting

### `IoctlGrabFailed`

Most common cause: another `tartarusd` instance is already running.

Check with:

```bash
tartarusctl status
tartarusctl quit
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
tartarusctl find-tartarus
ls -l /dev/input/eventX   # replace eventX with your actual node
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
