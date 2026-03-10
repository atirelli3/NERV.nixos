# Architecture

How NERV.nixos is structured, how modules compose, and how data flows through the system.

---

## Overview

NERV.nixos is a **NixOS library flake** — a reusable NixOS module collection consumed by host flakes. It is not an application; it produces no binaries. The entire codebase is declarative Nix configuration.

**Key design decisions:**

- All NERV-specific options live under a `nerv.*` namespace to prevent collisions with upstream NixOS options
- Security-critical modules (kernel, security, nix daemon) are always-on and opaque — no `enable` toggle
- Optional services are disabled by default; a single `nerv.<service>.enable = true` activates them
- The flake exports `nixosModules.default` (full suite) and granular sub-exports for host flakes that need only a subset

---

## Layer diagram

```
┌─────────────────────────────────────────────────────┐
│                    flake.nix                        │
│   inputs: nixpkgs, lanzaboote, home-manager,        │
│           disko, impermanence                       │
│   exports: nixosModules.default                     │
│   reference: nixosConfigurations.host               │
└───────────────────────┬─────────────────────────────┘
                        │ imports
                        ▼
┌─────────────────────────────────────────────────────┐
│              modules/default.nix                    │
│   imports: [ ./system  ./services  ../home ]        │
└──────┬────────────────┬────────────────┬────────────┘
       │                │                │
       ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  system/     │  │  services/   │  │  home/       │
│              │  │              │  │              │
│ identity     │  │ openssh      │  │ default.nix  │
│ hardware     │  │ pipewire     │  │ (HM wiring)  │
│ kernel       │  │ bluetooth    │  └──────────────┘
│ security     │  │ printing     │
│ nix          │  │ zsh          │
│ boot         │  └──────────────┘
│ disko        │
│ impermanence │
│ secureboot   │
└──────────────┘
       ▲
       │ consumes options from
┌──────────────────────────────────┐
│        hosts/configuration.nix  │
│  nerv.hostname = "my-laptop"     │
│  nerv.hardware.cpu = "amd"       │
│  nerv.disko.layout = "btrfs"     │
│  ...                             │
└──────────────────────────────────┘
```

---

## Option resolution flow

1. `flake.nix` constructs a `nixosSystem` call combining:
   - Upstream module inputs (lanzaboote, home-manager, impermanence, disko NixOS modules)
   - `self.nixosModules.default` (NERV module tree)
   - An inline `host` attrset with default `nerv.*` option values
   - `./hosts/configuration.nix` (machine-specific overrides)

2. The NixOS module system merges all modules; `nerv.*` options declared throughout `modules/` become available

3. `hosts/configuration.nix` sets required values and opt-in flags

4. Each module's `config = lib.mkIf cfg.enable { ... }` body evaluates conditionally

5. `nixos-rebuild switch` triggers the build and activation

---

## Module opacity levels

| Level | Meaning | Examples |
|-------|---------|---------|
| **Fully opaque** | No user options; always applies. Use `lib.mkForce` to override. | `kernel.nix`, `security.nix`, `nix.nix` |
| **Always-on** | Activated unconditionally, no enable toggle. | `packages.nix` |
| **Disabled by default** | Requires explicit `enable = true`. | `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `secureboot.nix`, `impermanence.nix` |
| **Enabled by default** | Active unless overridden. | `zsh.nix`, `home/default.nix` |

---

## Disk layout branching

`nerv.disko.layout` drives two parallel configuration branches:

```
nerv.disko.layout
       │
       ├── "btrfs" ──► GPT → 1G ESP → LUKS (cryptroot) → BTRFS
       │                     Subvolumes: @, @root-blank, @home, @nix, @persist, @log
       │                     Impermanence: initrd rollback service (@root-blank → @)
       │
       └── "lvm"   ──► GPT → 1G ESP → LUKS (cryptroot) → LVM VG lvmroot
                             LVs: swap, store (/nix), persist (/persist)
                             Impermanence: / mounted as tmpfs
```

`modules/system/disko.nix` uses `lib.mkMerge` with `lib.mkIf isBtrfs` / `lib.mkIf isLvm` branches. Shared fragments (`sharedEsp`, `sharedLuksOuter`) are Nix let-bindings reused by both branches.

---

## Secure Boot flow

```
nerv.secureboot.enable = true
          │
          ▼
    Boot 1 (Setup Mode detected)
    secureboot-enroll-keys.service
          │
          ├── sbctl enroll-keys --microsoft
          ├── write /var/lib/secureboot-keys-enrolled
          └── reboot
                    │
                    ▼
          Boot 2 (Secure Boot enforcing)
          secureboot-enroll-tpm2.service
                    │
                    ├── systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7
                    └── write /var/lib/secureboot-setup-done
                                      │
                                      ▼
                          All subsequent boots: TPM2 auto-unlock
```

`secureboot.nix` must be the **last import** in `modules/system/default.nix` because it sets `boot.loader.systemd-boot.enable = lib.mkForce false` to override the unconditional `true` set in `boot.nix`.

---

## State management

| Data | Location | Persistence |
|------|----------|-------------|
| Ephemeral root | `/` | Wiped on every reboot (BTRFS rollback or tmpfs) |
| Nix store | `/nix` (`@nix` subvolume or LVM LV) | Never wiped |
| Persistent state | `/persist` (`@persist` subvolume or LVM LV) | Survives reboots via `environment.persistence` bind-mounts |
| Logs | `/var/log` (`@log` subvolume) | BTRFS: dedicated subvolume, never wiped; LVM: bind-mounted from `/persist` |
| SSH host keys | `/etc/ssh/ssh_host_*` → `/persist` | Persisted via `environment.persistence` |
| Secure Boot keys | `/var/lib/sbctl` → `/persist` | Persisted via `environment.persistence` |
| AIDE database | `/var/lib/aide/aide.db` | Not automatically persisted — initialize after first boot |

---

## Adding new modules

### New system module (opaque, always-on)

```bash
# 1. Create the module file
touch modules/system/mymodule.nix

# 2. Register it in the aggregator
# modules/system/default.nix — add: ./mymodule.nix
```

Pattern:
```nix
# modules/system/mymodule.nix
#
# One-line description of what this module does.
{ pkgs, ... }: {
  # config goes here — no options, no enable toggle
}
```

### New optional service

```bash
touch modules/services/myservice.nix
# Add: ./myservice.nix  to modules/services/default.nix
```

Pattern:
```nix
# modules/services/myservice.nix
#
# One-line description.
{ config, lib, pkgs, ... }:
let cfg = config.nerv.myservice; in {
  options.nerv.myservice.enable = lib.mkEnableOption "my service";

  config = lib.mkIf cfg.enable {
    # service config
  };
}
```

### New host

```nix
# flake.nix — add to nixosConfigurations:
myhostname = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager
    disko.nixosModules.disko
    impermanence.nixosModules.impermanence
    self.nixosModules.default
    { nerv.hostname = "myhostname"; /* ... */ }
    ./hosts/myhostname-configuration.nix
  ];
};
```

---

## Cross-cutting concerns

**Validation:** All validation is at evaluation time via NixOS `assertions` and `lib.types`. No runtime validation layer exists. Run `nix flake check` to surface all type errors and assertion failures before deployment.

**Authentication:** SSH key-based only by default. `sudo` restricted to `wheel` group. Nix daemon accessible to `@wheel` only. Root SSH login disabled unconditionally.

**Logging:** systemd journal is the primary log sink. `auditd` writes to `/var/log/audit/audit.log`. AIDE integrity checks log to `journalctl -u aide-check`.

**Import order:** `secureboot.nix` must be the last entry in `modules/system/default.nix` — it overrides `systemd-boot.enable` with `lib.mkForce false`. This is documented in both `default.nix` and `secureboot.nix`.
