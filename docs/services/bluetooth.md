# Service: Bluetooth

**File:** `modules/services/bluetooth.nix`

Bluetooth with OBEX file transfer and MPRIS media proxy. Disabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.bluetooth.enable` | `bool` | `false` | Enable Bluetooth with OBEX and MPRIS proxy. |

---

## What it enables

| Feature | Details |
|---------|---------|
| BlueZ stack | `hardware.bluetooth.enable = true` |
| Bluetooth management UI | `services.blueman.enable = true` |
| OBEX file transfer | `services.obexd.enable = true`; auto-accepts to `~/Downloads` |
| PipeWire Bluetooth | `services.pipewire.wireplumber.enable = true` with BT profiles |
| MPRIS proxy | `systemd.user.services.mpris-proxy` — maps headset media buttons to MPRIS |
| Avahi/mDNS | `services.avahi.enable = true` |

---

## Example

```nix
nerv.bluetooth.enable = true;
```

---

## Usage

```bash
# Open Bluetooth manager UI
blueman-manager

# Command-line pairing
bluetoothctl
> scan on
> pair AA:BB:CC:DD:EE:FF
> connect AA:BB:CC:DD:EE:FF
> trust AA:BB:CC:DD:EE:FF

# Check BlueZ service
systemctl status bluetooth

# Check OBEX daemon
systemctl status obexd
```

---

## OBEX file transfer

When `obexd` is running, incoming Bluetooth file transfers are accepted automatically and saved to `~/Downloads`.

To send a file to a paired device:
```bash
bluetooth-sendto --device=AA:BB:CC:DD:EE:FF /path/to/file
```

---

## MPRIS proxy

The `mpris-proxy` systemd user service bridges Bluetooth headset media buttons (play/pause/next/prev) to MPRIS-compatible media players (Spotify, VLC, etc.).

```bash
# Check MPRIS proxy status
systemctl --user status mpris-proxy
```

---

## Notes

- Enabling Bluetooth also enables `services.avahi` (mDNS). This is shared with the Printing module — enabling either implies Avahi is on.
- Bluetooth audio requires `nerv.audio.enable = true` for PipeWire to handle BT audio profiles (A2DP, HSP/HFP).
