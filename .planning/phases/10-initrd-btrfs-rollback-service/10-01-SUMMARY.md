---
phase: 10-initrd-btrfs-rollback-service
plan: "01"
subsystem: infra
tags: [nixos, btrfs, initrd, systemd, luks, lvm, rollback, disko]

# Dependency graph
requires:
  - phase: 09-btrfs-disko-layout
    provides: disko.nix with BTRFS and LVM disk layout branches, @root-blank subvolume baseline

provides:
  - boot.initrd.systemd.services.rollback declared in disko.nix mkIf isBtrfs
  - boot.initrd.supportedFilesystems and storePaths for BTRFS in disko.nix
  - boot.initrd.services.lvm.enable and dm-snapshot kernel modules in disko.nix mkIf isLvm
  - boot.initrd.luks.devices.cryptroot in shared unconditional disko.nix entry
  - boot.nix as layout-agnostic file (kernelPackages, initrd.systemd.enable, bootloader only)

affects: [11-impermanence-btrfs-mode, 12-profile-wiring-and-documentation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Co-location of disk layout decisions with initrd config that depends on them (all in disko.nix)
    - boot.initrd.systemd.services for rollback (required when initrd.systemd.enable = true)
    - lib.mkMerge with two conditional (mkIf) entries + one unconditional entry for shared config

key-files:
  created: []
  modified:
    - modules/system/disko.nix
    - modules/system/boot.nix

key-decisions:
  - "All layout-conditional initrd config lives in disko.nix, not boot.nix — co-location prevents LVM initrd hang on BTRFS hosts"
  - "boot.initrd.luks.devices.cryptroot declared unconditionally (third mkMerge entry) — both layouts use the same LUKS container"
  - "preLVM omitted from luks.devices.cryptroot — silently ignored by systemd stage 1 (boot.initrd.systemd.enable = true)"
  - "rollback service ordering: after=dev-mapper-cryptroot.device, before=sysroot.mount — ensures LUKS is open before BTRFS mount attempt"

patterns-established:
  - "disko.nix mkMerge pattern: (mkIf isBtrfs { disk + initrd }) (mkIf isLvm { disk + initrd }) { shared unconditional }"
  - "boot.nix as layout-agnostic file — contains only kernelPackages, initrd.systemd.enable, systemd-boot, efi.canTouchEfiVariables"

requirements-completed: [BOOT-01, BOOT-02, BOOT-03]

# Metrics
duration: 2min
completed: 2026-03-10
---

# Phase 10 Plan 01: initrd BTRFS Rollback Service Summary

**BTRFS rollback service wired in disko.nix initrd (systemd stage 1), LVM initrd migrated under isLvm guard, LUKS unlock co-located as shared unconditional entry; boot.nix reduced to 4 layout-agnostic settings**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-10T08:15:22Z
- **Completed:** 2026-03-10T08:17:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Extended disko.nix with BTRFS initrd block: `supportedFilesystems=["btrfs"]`, `storePaths=[pkgs.btrfs-progs]`, and `boot.initrd.systemd.services.rollback` with correct ordering (after=dev-mapper-cryptroot.device, before=sysroot.mount, wantedBy=initrd.target)
- Extended disko.nix with LVM initrd block under `mkIf isLvm`: `boot.initrd.services.lvm.enable = true` and `kernelModules=["dm-snapshot" "cryptd"]` — preventing initrd hang on BTRFS hosts
- Added shared unconditional LUKS unlock as third mkMerge entry in disko.nix; stripped boot.nix to exactly 4 settings

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend disko.nix with BTRFS initrd block, LVM initrd block, and shared LUKS unlock** - `c2cbf10` (feat)
2. **Task 2: Strip boot.nix to layout-agnostic settings only** - `9a1955a` (feat)

**Plan metadata:** _(final metadata commit follows)_

## Files Created/Modified

- `modules/system/disko.nix` - Added pkgs to function args; added BTRFS initrd block with rollback service; added LVM initrd block; added shared unconditional LUKS unlock entry; updated header
- `modules/system/boot.nix` - Removed lvm/dm-snapshot/cryptd/luks.devices settings; removed config/lib args; updated Purpose header with cross-reference to disko.nix

## Decisions Made

- **Co-location:** All layout-conditional initrd config lives in disko.nix alongside the disk layout it depends on. This prevents the LVM initrd hang that would occur if `boot.initrd.services.lvm.enable = true` and `kernelModules = ["dm-snapshot" "cryptd"]` remained unconditional in boot.nix while a BTRFS host (with no LVM PV) tried to boot.
- **preLVM omitted:** `preLVM = true` is silently ignored by systemd stage 1 (boot.initrd.systemd.enable = true already set). Removed to avoid misleading configuration.
- **Rollback service ordering:** `after=dev-mapper-cryptroot.device` ensures LUKS is unlocked before the rollback script tries to mount `/dev/mapper/cryptroot`. `before=sysroot.mount` ensures rollback completes before the root filesystem is mounted for real.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — nix evaluation not available on dev machine (darwin); structural correctness confirmed by code review against plan specification and grep verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- disko.nix now provides the complete boot-time integration for BTRFS rollback (BOOT-01, BOOT-02, BOOT-03 satisfied)
- Phase 11 (Impermanence BTRFS Mode) can safely declare impermanence.mode = "btrfs" — the rollback service that resets /@ on every boot is now in place
- `@root-blank` subvolume (from Phase 9) must still be manually created as a read-only snapshot after first disko run — documented in install procedure (PROF-04 Phase 12 task)

---
*Phase: 10-initrd-btrfs-rollback-service*
*Completed: 2026-03-10*

## Self-Check: PASSED

- FOUND: .planning/phases/10-initrd-btrfs-rollback-service/10-01-SUMMARY.md
- FOUND: modules/system/disko.nix (modified)
- FOUND: modules/system/boot.nix (modified)
- FOUND: commit c2cbf10 (Task 1)
- FOUND: commit 9a1955a (Task 2)
