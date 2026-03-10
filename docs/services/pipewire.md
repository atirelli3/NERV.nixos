# Service: PipeWire (Audio)

**File:** `modules/services/pipewire.nix`

PipeWire audio stack with low-latency defaults, AirPlay sink, and ALSA/PulseAudio compatibility. Disabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.audio.enable` | `bool` | `false` | Enable PipeWire audio stack. |

---

## What it enables

| Feature | NixOS option |
|---------|-------------|
| PipeWire daemon | `services.pipewire.enable = true` |
| ALSA compatibility | `services.pipewire.alsa.enable = true`, `alsa.support32Bit = true` |
| PulseAudio compatibility | `services.pipewire.pulse.enable = true` |
| PipeWire native | `services.pipewire.jack.enable = false` (JACK disabled by default) |
| AirPlay sink (RAOP) | `libpipewire-module-raop-discover` |
| AirPlay firewall | `services.pipewire.raopOpenFirewall = true` (opens UDP 6001–6002) |
| RealtimeKit | `security.rtkit.enable = true` |

### Low-latency configuration

Default quantum: 1024 samples at 48000 Hz ≈ 21ms

```
# Applied via pipewire.conf extraConfig
quantum    = 1024
rate       = 48000
min-quantum = 512
max-quantum = 8192
```

---

## Installed packages

| Package | Use |
|---------|-----|
| `pwvucontrol` | Per-application PipeWire volume control |
| `helvum` | PipeWire graph patchbay (routing UI) |

---

## Example

```nix
nerv.audio.enable = true;
```

---

## Usage

```bash
# Check PipeWire status
systemctl --user status pipewire

# Open volume control
pwvucontrol

# Open patchbay
helvum

# List audio devices (PulseAudio compat)
pactl list short sinks
pactl list short sources

# List PipeWire graph
pw-cli list-objects
```

---

## Adjusting latency

For lower latency (gaming, audio production):

```nix
# hosts/configuration.nix
{ lib, ... }: {
  services.pipewire.extraConfig.pipewire."10-nerv-latency" = lib.mkForce {
    "context.properties" = {
      "default.clock.quantum"     = 512;
      "default.clock.min-quantum" = 256;
      "default.clock.max-quantum" = 2048;
      "default.clock.rate"        = 48000;
    };
  };
}
```

For higher stability (general desktop use), the defaults (1024/48000) are fine.

---

## AirPlay sink

When enabled, the system appears as an AirPlay 2 receiver. You can stream audio from an iPhone, iPad, or Mac directly to this machine via AirPlay.

UDP ports 6001–6002 are opened in the firewall automatically.
