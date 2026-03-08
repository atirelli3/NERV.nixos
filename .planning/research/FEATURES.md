# Features Research: nerv.nixos

**Project:** nerv.nixos — NixOS module library refactor
**Focus:** Module options API — what to expose, what to keep opinionated
**Confidence:** HIGH (based on codebase analysis + NixOS module system patterns)

---

## Table Stakes Options

Every host will need to set these. These become `options.nerv.*` with sensible defaults.

### Identity / Locale

| Option | Type | Default | Maps to |
|--------|------|---------|---------|
| `nerv.hostname` | `str` | `"nixos"` | `networking.hostName` |
| `nerv.locale.timeZone` | `str` | `"UTC"` | `time.timeZone` |
| `nerv.locale.keyMap` | `str` | `"us"` | `console.keyMap` |
| `nerv.locale.defaultLocale` | `str` | `"en_US.UTF-8"` | `i18n.defaultLocale` |
| `nerv.primaryUser` | `str` | — (required) | `users.users.<name>` group membership |

### Hardware

| Option | Type | Default | Maps to |
|--------|------|---------|---------|
| `nerv.hardware.cpu` | `enum ["amd" "intel" "other"]` | `"other"` | `hardware.cpu.*.updateMicrocode`, kernel params |
| `nerv.hardware.gpu` | `enum ["amd" "nvidia" "intel" "none"]` | `"none"` | GPU drivers + kernel modules |

### SSH

| Option | Type | Default | Maps to |
|--------|------|---------|---------|
| `nerv.openssh.enable` | `bool` | `true` | `services.openssh.enable` |
| `nerv.openssh.allowUsers` | `listOf str` | `[]` (all) | `services.openssh.settings.AllowUsers` |
| `nerv.openssh.passwordAuth` | `bool` | `false` | `services.openssh.settings.PasswordAuthentication` |
| `nerv.openssh.kbdInteractiveAuth` | `bool` | `false` | `services.openssh.settings.KbdInteractiveAuthentication` |
| `nerv.openssh.port` | `port` | `22` | `services.openssh.ports` |

### Impermanence

| Option | Type | Default | Maps to |
|--------|------|---------|---------|
| `nerv.impermanence.enable` | `bool` | `false` | `environment.persistence` setup |
| `nerv.impermanence.persistPath` | `str` | `"/persist"` | Base path for persistence |
| `nerv.impermanence.extraDirs` | `listOf str` | `[]` | Additional system dirs to persist |
| `nerv.impermanence.users` | `attrsOf (listOf str)` | `{}` | Per-user dirs to persist |

### Home Manager

| Option | Type | Default | Maps to |
|--------|------|---------|---------|
| `nerv.home.enable` | `bool` | `false` | HM NixOS module activation |
| `nerv.home.users` | `listOf str` | `[]` | HM user configs to manage |

---

## Differentiating Options

Useful for some hosts but not all. Exposed as options with safe defaults.

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `nerv.audio.enable` | `bool` | `false` | PipeWire — opt-in (servers don't need audio) |
| `nerv.bluetooth.enable` | `bool` | `false` | Bluetooth — opt-in |
| `nerv.printing.enable` | `bool` | `false` | CUPS — opt-in |
| `nerv.secureboot.enable` | `bool` | `false` | Lanzaboote — opt-in (VM incompatible) |
| `nerv.kernel.package` | `package` | `pkgs.linuxPackages_latest` | Override kernel |
| `nerv.nix.autoUpdate` | `bool` | `false` | Auto upgrades — opt-in |
| `nerv.nix.gcInterval` | `str` | `"weekly"` | GC frequency |

---

## Anti-Features (deliberately NOT exposed)

These stay hardcoded/opinionated in the base. Exposing them defeats the purpose of a hardened base.

| Feature | Why NOT an option |
|---------|-------------------|
| `PasswordAuthentication = true` toggle | Security regression — users who need it can `lib.mkForce` it |
| Per-sysctl boolean toggles | Too granular; defeats hardening coherence |
| DE/WM/DM configuration | Belongs in host flake, not base modules |
| Full home impermanence | Too complex for a general base — host-flake concern |
| Audit rule tuning | Keep security defaults opinionated; document override path |
| `AllowRoot` SSH | Hard no — never expose this as an easy option |

---

## Option Dependencies

| If this option is set... | ...then this also activates |
|--------------------------|------------------------------|
| `nerv.hardware.cpu = "amd"` | `hardware.cpu.amd.updateMicrocode = true`, `boot.kernelParams += ["amd_iommu=on"]` |
| `nerv.hardware.cpu = "intel"` | `hardware.cpu.intel.updateMicrocode = true` |
| `nerv.hardware.gpu = "nvidia"` | `services.xserver.videoDrivers = ["nvidia"]`, `hardware.nvidia.*` |
| `nerv.openssh.allowUsers != []` | `services.openssh.settings.AllowUsers` set (verify no typos!) |
| `nerv.bluetooth.enable` | `services.avahi.enable = true` (for OBEX) |
| `nerv.printing.enable` | `services.avahi.enable = true` (for mDNS discovery) |
| `nerv.impermanence.enable` | `/persist` must exist on disk; sbctl dir persisted automatically |
| `nerv.home.enable` | `home-manager.nixosModules.home-manager` imported; `stateVersion` inherited |

---

## MVP Priority Ordering

1. `nerv.hostname`, `nerv.locale.*`, `nerv.primaryUser` — every host needs these
2. `nerv.hardware.cpu`, `nerv.hardware.gpu` — machine-specific, high-value
3. `nerv.openssh.*` — security-critical, most common override target
4. `nerv.audio.enable`, `nerv.bluetooth.enable` — common desktop toggles
5. `nerv.impermanence.*` — advanced, opt-in
6. `nerv.home.*` — advanced, opt-in
7. `nerv.secureboot.enable` — advanced, hardware-dependent
