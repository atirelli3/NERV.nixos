# Architecture

**Analysis Date:** 2026-03-06

## Pattern Overview

**Overall:** Modular NixOS Flake Configuration

This is a NixOS system configuration repository following a composable, flake-based architecture. System definitions are assembled by composing a host-specific configuration with reusable, single-responsibility modules. The pattern emphasises declarative infrastructure-as-code: every system property — from disk layout to kernel hardening to shell aliases — is expressed as Nix code and evaluated at build time.

**Key Characteristics:**
- Flake-pinned inputs ensure fully reproducible builds (`nixpkgs/nixos-unstable` + `lanzaboote` + optionally `impermanence`)
- Host configurations (`base/`, `server/`) act as composition roots; they import `modules/` for shared concerns
- No runtime scripts or mutable state outside explicitly declared persistence paths
- Security-first design: full-disk encryption (LUKS-on-LVM), Secure Boot (lanzaboote/sbctl), TPM2-sealed LUKS unlock, AppArmor, auditd, fail2ban, endlessh tarpit
- The `.template/` directory holds reference implementations used as starting points, not deployed directly

## Layers

**Flake Entry Point:**
- Purpose: Declares all external inputs and assembles `nixosConfigurations` outputs
- Location: `base/flake.nix`
- Contains: Input pins (`nixpkgs`, `lanzaboote`), host definition (`nixos-base`), module list
- Depends on: `./configuration.nix`, `../modules/*`
- Used by: `nixos-rebuild`, `nix build`, `nix flake` CLI

**Host Configuration:**
- Purpose: Machine-specific settings — hostname, filesystem mounts, boot loader, locale, users, stateVersion
- Location: `base/configuration.nix`, `server/configuration.nix`
- Contains: `fileSystems`, `swapDevices`, `boot`, `networking`, `users`, `time`, `i18n`, `system.stateVersion`
- Depends on: `./hardware-configuration.nix` (generated, not committed), shared `modules/`
- Used by: Flake outputs

**Disk Layout:**
- Purpose: Declarative partition/filesystem specification evaluated by the Disko tool at install time
- Location: `base/disko-configuration.nix`, `server/disko-configuration.nix`
- Contains: GPT table, ESP, LUKS container, LVM volume group and logical volumes
- Depends on: Nothing (standalone Disko input)
- Used by: Initial system installation; disk labels must stay in sync with `configuration.nix` `fileSystems`

**Shared Modules:**
- Purpose: Reusable, single-concern NixOS modules imported selectively by host flakes
- Location: `modules/`
- Contains: One `.nix` file per concern (bluetooth, hardware, kernel, nix, openssh, pipewire, printing, secureboot, security, zsh)
- Depends on: Standard NixOS module system (`config`, `lib`, `pkgs` arguments)
- Used by: Any host flake that lists the module in its `modules = [ ... ]` array

**Reference Templates:**
- Purpose: Illustrative, more complete configurations demonstrating advanced patterns (impermanence, full kernel hardening)
- Location: `.template/`
- Contains: `flake.nix`, `configuration.nix`, `configuration1.nix`, `disko-configuration.nix`, `flake2.nix`, `secureboot-configuration.nix`
- Depends on: Not evaluated by any deployed flake
- Used by: Developer reference when building new host configurations

## Data Flow

**System Build:**
1. Developer runs `nixos-rebuild switch --flake /etc/nixos#nixos-base`
2. Nix evaluates `base/flake.nix`, resolving pinned inputs from `flake.lock`
3. `nixpkgs.lib.nixosSystem` merges `base/configuration.nix` with each listed module
4. NixOS module system merges all `options`/`config` attribute sets, applying `lib.mkForce` where needed to resolve conflicts (e.g., `boot.loader.systemd-boot.enable = false` overridden by `secureboot.nix`)
5. Nix builds the system closure and activates it

**Disk Provisioning (install time):**
1. `disko-configuration.nix` is evaluated by the Disko tool
2. Partitions are created: ESP (`NIXBOOT`), LUKS container (`NIXLUKS`)
3. LUKS opens to LVM PV → VG `lvmroot` → LVs for swap, root (ext4 or tmpfs target), optionally store/persist/home
4. `configuration.nix` `fileSystems` bind disk labels to NixOS mount points

**First-Boot Secure Boot Setup (base host):**
1. `secureboot-enroll-keys.service` fires — detects UEFI Setup Mode, enrolls sbctl keys, reboots
2. `secureboot-enroll-tpm2.service` fires on second boot — verifies Secure Boot active, binds LUKS to TPM2 PCRs 0+7

**State Management:**
- `base/` host: standard stateful root (ext4 `/`, no impermanence)
- `server/` host (and `.template/`): tmpfs root — state resets on every reboot; only paths declared in `environment.persistence."/persist"` survive via bind mounts managed by the `impermanence` NixOS module

## Key Abstractions

**NixOS Module:**
- Purpose: A self-contained Nix expression that contributes options/config to the merged system
- Examples: `modules/bluetooth.nix`, `modules/kernel.nix`, `modules/secureboot.nix`
- Pattern: `{ config, lib, pkgs, ... }: { <nixos-options> = <values>; }`

**Disko Configuration:**
- Purpose: Declarative disk layout evaluated once at install time; source of truth for partition labels
- Examples: `base/disko-configuration.nix`, `server/disko-configuration.nix`
- Pattern: `{ disko.devices.disk.<name> = { device = ...; content = { type = "gpt"; partitions = { ... }; }; }; }`

**Flake Output:**
- Purpose: Named `nixosConfigurations.<hostname>` attribute consumed by `nixos-rebuild`
- Examples: `base/flake.nix` defines `nixos-base`; `.template/flake.nix` defines `nixos`
- Pattern: `nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ ... ]; }`

**Persistence Declaration (impermanence pattern):**
- Purpose: Explicitly enumerate paths that must survive a tmpfs root reboot
- Examples: `.template/configuration.nix` `environment.persistence."/persist"` block
- Pattern: `environment.persistence."/persist" = { hideMounts = true; directories = [ ... ]; files = [ ... ]; };`

## Entry Points

**base/flake.nix:**
- Location: `base/flake.nix`
- Triggers: `nixos-rebuild`, `nix build .#nixos-base`, `nix flake update`
- Responsibilities: Pin inputs, declare `nixos-base` host, compose modules

**server/configuration.nix:**
- Location: `server/configuration.nix`
- Triggers: Referenced by a host flake (not yet present in `server/`)
- Responsibilities: Server-specific filesystem layout with tmpfs root and separate `/nix`, `/persist`, `/home` LVs

## Error Handling

**Strategy:** Declarative conflicts resolved at evaluation time via `lib.mkForce` priority overrides. Build failures surface as Nix evaluation errors before any system change is applied.

**Patterns:**
- `lib.mkForce` used in `base/configuration.nix` to override Disko-generated `fileSystems` mounts
- `lib.mkForce false` in `modules/secureboot.nix` to disable the default `systemd-boot` loader before lanzaboote takes over
- First-boot systemd services use flag files (`/var/lib/secureboot-keys-enrolled`, `/var/lib/secureboot-setup-done`) to guard against re-execution

## Cross-Cutting Concerns

**Logging:** systemd journal by default; `security.auditd` writes to `/var/log/audit/audit.log`; AIDE integrity check results to journal via `journalctl -u aide-check`
**Validation:** Nix type system and NixOS option declarations enforce correctness at evaluation time; no runtime validation layer
**Authentication:** SSH key-only (`PasswordAuthentication = false`); sudo restricted to wheel group; LUKS unlocked via TPM2 (PCRs 0+7) post-setup; users declared immutably (`mutableUsers = false`) in template

---

*Architecture analysis: 2026-03-06*
