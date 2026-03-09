# Stack Research: nerv.nixos v2.0

**Project:** nerv.nixos — Stateless Disk Layout (BTRFS + impermanence)
**Mode:** Ecosystem — Stack dimension
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| disko | v1.13.0 (already pinned) | Declarative disk layout; adds BTRFS content type | Already in flake inputs; btrfs subvolume support added in v1.x |
| nix-community/impermanence | HEAD (no release tags; pin to commit or nixpkgs-unstable follow) | `environment.persistence` declarative bind-mounts | De-facto community standard; much cleaner than custom tmpfiles.rules |
| NixOS boot.initrd.systemd | Built-in (NixOS 25.11) | systemd-based initrd for BTRFS rollback service | Already enabled in boot.nix; `postDeviceCommands` incompatible with systemd initrd |
| btrfs-progs | nixpkgs (in boot.initrd.supportedFilesystems) | BTRFS tools available in initrd for snapshot/delete | Must add "btrfs" to `boot.initrd.supportedFilesystems` |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| impermanence.nixosModules.impermanence | (above) | Provides `environment.persistence` NixOS option | Add to nixosConfigurations modules list for all profiles using persistence |
| boot.initrd.systemd.services.rollback | NixOS built-in | systemd service unit in initrd for BTRFS rollback | Desktop/host profile only — server uses tmpfs (no rollback needed) |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| nix flake check | Verify module evaluation before deploy | Run after each phase; dev machine lacks nix but NERV.nixos target has it |
| disko --dry-run | Preview disk layout without applying | Use on target machine before first install |
| btrfs subvolume list /mnt | Verify subvolumes after disko run | Run during install validation |

## Installation

```nix
# flake.nix — impermanence module already declared as input; just wire it:
impermanence.nixosModules.impermanence  # add to all nixosConfigurations modules lists

# disko — already wired; no changes to inputs

# boot.initrd — add btrfs to supported filesystems:
boot.initrd.supportedFilesystems = [ "btrfs" ];
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| boot.initrd.systemd.services for rollback | boot.initrd.postDeviceCommands | ONLY when systemd initrd is NOT used — incompatible with boot.nix |
| disko BTRFS content type | Manual fileSystems entries | Never — disko provides declarative disk partitioning; manual is fragile |
| environment.persistence (upstream module) | Custom bind-mounts via tmpfiles.rules (current) | Custom approach is fine but requires manual maintenance; upstream module has better API |
| LUKS → btrfs content chain | LUKS → lvm_pv → btrfs LV | lvm_pv approach adds unnecessary complexity for BTRFS; direct is simpler |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| boot.initrd.postDeviceCommands | Incompatible with systemd initrd (already enabled in boot.nix) | boot.initrd.systemd.services.rollback |
| impermanence input with nixpkgs.follows | Upstream impermanence has no nixpkgs input — setting follows causes eval error | Remove nixpkgs.follows from impermanence input (Phase 7 learned this) |
| @home on tmpfs | Data loss on every reboot | @home as persistent BTRFS subvolume |
| mount / as tmpfs on desktop | /nix store too large for RAM | tmpfs root only for server; desktop uses BTRFS @  |

## Stack Patterns by Variant

**If desktop/host profile (nerv.disko.layout = "btrfs"):**
- disko: disk → gpt → {ESP vfat, luks → btrfs → subvolumes {@ @root-blank @home @nix @persist}}
- boot.initrd: add btrfs to supportedFilesystems; add rollback systemd service
- environment.persistence."/persist": declare dirs/files
- neededForBoot on @persist and @nix subvols

**If server/vm profile (nerv.disko.layout = "lvm"):**
- disko: disk → gpt → {ESP vfat, luks → lvm_pv → lvm_vg → {swap, store=/nix, persist=/persist}}
- fileSystems."/": tmpfs size=2G (from impermanence.nix full mode)
- environment.persistence."/persist": declare dirs/files
- neededForBoot on /persist LV

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| disko v1.13.0 | NixOS 25.11 | Already pinned in flake.nix |
| impermanence (HEAD/unstable) | NixOS 25.11 | No nixpkgs.follows (no nixpkgs input in upstream) |
| btrfs-progs | NixOS 25.11 kernel | Included via boot.initrd.supportedFilesystems = ["btrfs"] |

## Sources

- flake.nix (existing inputs: disko v1.13.0, impermanence already declared)
- modules/system/boot.nix (boot.initrd.systemd.enable = true confirmed)
- disk-layout-refactor.md (design specification)
- github.com/nix-community/impermanence (upstream module API)
- NixOS wiki: Impermanence (initrd systemd service pattern)

---
*Stack research for: nerv.nixos v2.0 stateless disk layout*
*Researched: 2026-03-09*
