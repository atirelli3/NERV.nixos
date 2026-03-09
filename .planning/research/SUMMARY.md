# Project Research Summary

**Project:** nerv.nixos v2.0 — Stateless Disk Layout
**Domain:** NixOS declarative disk layout (BTRFS + impermanence)
**Researched:** 2026-03-09
**Confidence:** HIGH

## Executive Summary

The v2.0 milestone adds stateless disk layouts for desktop (BTRFS + initrd snapshot rollback) and server (tmpfs root, already working in v1.0 full mode). The existing codebase is in a strong position: `impermanence.nixosModules.impermanence` is already wired in all 3 nixosConfigurations, `disko.nixosModules.disko` is already wired, and `impermanence.nix` already implements `environment.persistence` for server full mode. The primary v2.0 work is extending `disko.nix` with a BTRFS layout branch, adding an initrd rollback systemd service in `boot.nix`, and adding a "btrfs" mode to `impermanence.nix`.

The single highest-risk item is the initrd rollback service: `boot.nix` already sets `boot.initrd.systemd.enable = true`, which makes `boot.initrd.postDeviceCommands` incompatible. The rollback MUST use `boot.initrd.systemd.services.rollback`. BTRFS tools must be added to `boot.initrd.supportedFilesystems`. The LUKS device is `/dev/mapper/cryptroot` (not a by-label path) — this must be used in the rollback script.

The server profile is nearly done: `impermanence.nix` full mode already emits `environment.persistence` with the correct directories and files. The remaining server work is adding `nerv.disko.layout = "lvm"` as an explicit option and verifying the existing LVM full-mode disko layout is wired correctly in the updated disko.nix module.

## Key Findings

### Recommended Stack

No new flake inputs required. Both disko (v1.13.0, already pinned) and impermanence (already declared) are sufficient. The upstream impermanence module is already in all nixosConfigurations modules lists. Only code changes within existing modules are needed.

**Core technologies:**
- `disko v1.13.0`: BTRFS content type + subvolumes attrset (already in flake, add BTRFS branch to disko.nix)
- `impermanence.nixosModules.impermanence`: `environment.persistence` API (already wired, just add btrfs mode to impermanence.nix)
- `boot.initrd.systemd.services`: initrd systemd service for rollback (NixOS built-in, no new inputs)
- `boot.initrd.supportedFilesystems = ["btrfs"]`: includes btrfs-progs + kernel module in initrd

### Expected Features

**Must have (table stakes):**
- BTRFS subvolumes: @, @root-blank, @home, @nix, @persist
- initrd BTRFS rollback via `boot.initrd.systemd.services.rollback`
- environment.persistence for both btrfs and lvm-full modes
- Minimum persistence: machine-id, SSH host keys, /var/log, /var/lib/nixos, /var/lib/systemd
- nerv.disko.layout = "btrfs" | "lvm" option
- BTRFS mount options: compress=zstd:3, noatime, space_cache=v2

**Should have (differentiators):**
- @log subvolume (optional persistent logs across desktop reboots)
- Configurable tmpfsSize for server profile

**Defer (v3+):**
- Snapper integration, BTRFS RAID, migration tooling

### Architecture Approach

Minimal-change extension of existing modules. disko.nix gets a `nerv.disko.layout` option that switches between BTRFS (desktop) and LVM (server/vm) branches. boot.nix gets BTRFS tools + rollback service conditional on layout. impermanence.nix gets a "btrfs" mode that provides environment.persistence without the tmpfs / (rollback handles root reset instead). Profile attrsets in flake.nix gain `nerv.disko.layout` declarations.

**Major components:**
1. `disko.nix` — BTRFS branch: GPT → ESP + LUKS → btrfs subvolumes {@, @root-blank, @home, @nix, @persist}
2. `boot.nix` — rollback service: `boot.initrd.systemd.services.rollback` deletes @ + snapshots @root-blank → @
3. `impermanence.nix` — btrfs mode: environment.persistence."/persist" for desktop (no tmpfs /)

### Critical Pitfalls

1. **postDeviceCommands incompatible with systemd initrd** — use `boot.initrd.systemd.services.rollback` exclusively; boot.nix already enables systemd initrd
2. **@root-blank must be read-only snapshot** — after disko run: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`; document in install procedure
3. **btrfs missing from initrd supportedFilesystems** — add `boot.initrd.supportedFilesystems = ["btrfs"]`; without this initrd cannot mount root
4. **Rollback device path must be `/dev/mapper/cryptroot`** — not a by-label path; BTRFS label is inside LUKS and not accessible by label until after unlock
5. **neededForBoot on @persist** — upstream impermanence module bind-mounts during early activation; /persist must be mounted first
6. **@nix subvolume mandatory** — if /nix is on @ it gets deleted by rollback; system is unbootable on next boot
7. **No swap file on BTRFS CoW** — BTRFS swap files require nodatacow; simpler to have no swap in BTRFS profile (or a separate swap partition)
8. **LVM initrd active on BTRFS layout (CRITICAL)** — boot.nix sets `preLVM = true` + `lvm.enable = true` unconditionally; must be disabled for BTRFS or initrd hangs scanning a device with no PV
9. **/var/log double-mount** — @log subvolume + environment.persistence both declaring /var/log causes conflict; exclude /var/log from persistence.directories in btrfs mode
10. **btrfs-progs missing from systemd initrd store** — must explicitly set `boot.initrd.systemd.storePaths = [pkgs.btrfs-progs]`

## Implications for Roadmap

**Phase numbering continues from v1.0 (last phase: 8) → v2.0 starts at Phase 9.**

### Phase 9: BTRFS Disko Layout
**Rationale:** Foundation — everything depends on the correct subvolumes existing on disk
**Delivers:** `nerv.disko.layout = "btrfs"` option in disko.nix; BTRFS subvolume branch; `nerv.disko.layout = "lvm"` explicit option for existing profiles
**Addresses:** BTRFS layout feature (table stakes)
**Avoids:** P8 (@nix as separate subvolume), P9 (no swap on BTRFS)

### Phase 10: initrd BTRFS Rollback Service
**Rationale:** Depends on Phase 9 (needs to know LUKS device name and subvolume names); highest-risk phase
**Delivers:** `boot.initrd.systemd.services.rollback` in boot.nix; `boot.initrd.supportedFilesystems = ["btrfs"]`
**Addresses:** Rollback feature (table stakes)
**Avoids:** P1 (must use systemd service, not postDeviceCommands), P3 (btrfs in supportedFilesystems), P4 (correct device path)

### Phase 11: Impermanence btrfs Mode + Persistence Rules
**Rationale:** Depends on Phase 9 (@persist subvolume); extends existing full-mode pattern
**Delivers:** `nerv.impermanence.mode = "btrfs"` in impermanence.nix; environment.persistence for desktop without tmpfs /
**Addresses:** Upstream impermanence module integration (table stakes), minimum persistence rules
**Avoids:** P5 (machine-id), P6 (SSH keys), P7 (neededForBoot), P11 (double-declaration)

### Phase 12: Profile Wiring, Documentation, and Install Procedure
**Rationale:** Wire all changes into flake.nix profiles; document the BTRFS-specific install procedure (read-only @root-blank snapshot)
**Delivers:** hostProfile with layout=btrfs + mode=btrfs; install walkthrough documentation; updated section headers on modified modules
**Addresses:** @root-blank read-only snapshot requirement (P2), profile configuration
**Avoids:** P2 (@root-blank created correctly at install time)

### Phase Ordering Rationale

- Phase 9 before 10: rollback service needs the LUKS device name and subvolume layout to be final
- Phase 9 before 11: persistence rules reference @persist subvolume path
- Phase 12 last: cannot update profiles until modules are complete; install docs need final module API

### Research Flags

- **Phase 10:** initrd systemd service `after` target — verify exact device unit name for `/dev/mapper/cryptroot` in NixOS 25.11 systemd initrd (should be `dev-mapper-cryptroot.device` per systemd naming convention but verify against actual NixOS unit names)
- **Phase 11:** neededForBoot on disko-generated BTRFS subvolume mounts — verify whether disko v1.13.0 supports `neededForBoot` on subvolume mounts or if a separate `fileSystems` override is needed

Phases with standard patterns (skip research-phase):
- **Phase 9:** BTRFS disko content type is well-documented; extending existing disko.nix is straightforward
- **Phase 12:** Documentation and profile wiring — standard nerv pattern

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | No new inputs; existing modules extend cleanly |
| Features | HIGH | Spec is detailed; community patterns well-established |
| Architecture | HIGH | Direct codebase analysis; module integration points clear |
| Pitfalls | HIGH | Most pitfalls directly traceable to existing code constraints |

**Overall confidence:** HIGH

### Gaps to Address

- **initrd systemd unit name for cryptroot device:** Use `dev-mapper-cryptroot.device` per systemd convention but verify during Phase 10 implementation with `systemctl list-units` on target
- **disko v1.13.0 BTRFS neededForBoot:** Check if `neededForBoot` can be set within disko subvolume definition or requires `fileSystems."..." = { neededForBoot = true; }` override in impermanence.nix

## Sources

### Primary (HIGH confidence)
- modules/system/disko.nix — existing LVM implementation to extend
- modules/system/boot.nix — `boot.initrd.systemd.enable = true` confirmed; LUKS device name "cryptroot" confirmed
- modules/system/impermanence.nix — full mode environment.persistence pattern to replicate
- flake.nix — profile structure; impermanence.nixosModules.impermanence already in all 3 nixosConfigurations
- disk-layout-refactor.md — design specification

### Secondary (MEDIUM confidence)
- willbush.dev/blog/impermanent-nixos — BTRFS initrd rollback NixOS pattern
- xeiaso.net/blog/paranoid-nixos-2021-07-18 — tmpfs root server pattern
- github.com/nix-community/impermanence — environment.persistence API

---
*Research completed: 2026-03-09*
*Ready for roadmap: yes*
