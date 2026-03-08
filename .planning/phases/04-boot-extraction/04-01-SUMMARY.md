---
phase: 04-boot-extraction
plan: "01"
subsystem: infra
tags: [nixos, boot, luks, initrd, systemd-boot, lvm, opaque-module]

# Dependency graph
requires:
  - phase: 03-system-modules-non-boot
    provides: Opaque module pattern established (kernel.nix, security.nix, nix.nix, hardware.nix)
provides:
  - modules/system/boot.nix — opaque NixOS module with initrd (systemd+LVM+LUKS) and bootloader (systemd-boot+EFI) config
  - NIXLUKS cross-reference comment in disko-configuration.nix (part of three-file comment set)
affects:
  - 04-02 (secureboot wiring — will import boot.nix, needs NIXLUKS label in sync)
  - 04-03 (boot block removal from configuration.nix — boot.nix must be imported first)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Opaque NixOS module: no nerv.* options, lib.mkForce is the escape hatch
    - Flat attribute style: boot.initrd.X rather than nested boot = { initrd = { X } }
    - Three-file LUKS comment set: boot.nix / disko-configuration.nix / secureboot.nix

key-files:
  created:
    - modules/system/boot.nix
  modified:
    - hosts/nixos-base/disko-configuration.nix

key-decisions:
  - "boot.nix is fully opaque (no nerv.* options) — lib.mkForce is the documented escape hatch"
  - "boot.kernelPackages = pkgs.linuxPackages_latest is present but overridden by kernel.nix via lib.mkForce pkgs.linuxPackages_zen"
  - "NIXLUKS cross-reference comment on disko-configuration.nix line 26 is the second of three required comment anchors"

patterns-established:
  - "Opaque boot module: all settings unconditional, no options declared"
  - "LUKS sync comment pattern: inline comment on label line referencing all files that must stay in sync"

requirements-completed:
  - STRUCT-02

# Metrics
duration: 5min
completed: "2026-03-07"
---

# Phase 4 Plan 01: Boot Extraction Summary

**Opaque boot.nix module extracted from configuration.nix with full initrd (systemd+LVM+LUKS) and systemd-boot/EFI config; NIXLUKS cross-reference comment added to disko-configuration.nix**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-07T10:51:54Z
- **Completed:** 2026-03-07T10:57:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created modules/system/boot.nix as a fully opaque NixOS module following the pattern from kernel.nix and security.nix
- Migrated boot block verbatim from hosts/nixos-base/configuration.nix with flat attribute style and all inline comments preserved
- Added the four-line header (Purpose, Options, Note, LUKS) required by the locked decision
- Added NIXLUKS cross-reference comment to disko-configuration.nix line 26, completing the second of three required sync anchors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/system/boot.nix** - `f890099` (feat)
2. **Task 2: Add LUKS cross-reference comment to disko-configuration.nix** - `556635a` (feat)

## Files Created/Modified

- `modules/system/boot.nix` — New opaque NixOS module with initrd (systemd.enable, lvm.enable, kernelModules, luks.devices."cryptroot") and bootloader (systemd-boot + EFI) configuration
- `hosts/nixos-base/disko-configuration.nix` — Added inline cross-reference comment on the NIXLUKS extraFormatArgs line

## Decisions Made

- boot.nix is fully opaque (no nerv.* options) — lib.mkForce is the documented escape hatch, consistent with kernel.nix
- boot.kernelPackages = pkgs.linuxPackages_latest is present in boot.nix but overridden at evaluation time by kernel.nix (lib.mkForce pkgs.linuxPackages_zen); kernel.nix remains the authoritative source
- boot block stays in configuration.nix until Plan 03 — this plan only creates the module, wiring happens later

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- nixos-rebuild is not available on this dev machine (expected — this is a development environment, not a NixOS machine). Build verification was skipped; the plan's done criteria acknowledge that build passes because configuration.nix still has the boot block and boot.nix is not yet imported.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- modules/system/boot.nix is ready to be imported in modules/system/default.nix (Plan 02 or 03)
- NIXLUKS cross-reference comment set: 1/3 complete (disko-configuration.nix done; secureboot.nix is Plan 02; boot.nix comment referencing secureboot.nix is already present)
- configuration.nix boot block is unchanged — removal happens in Plan 03 after wiring is verified

---
*Phase: 04-boot-extraction*
*Completed: 2026-03-07*
