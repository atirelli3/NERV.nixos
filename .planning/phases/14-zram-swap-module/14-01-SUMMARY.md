---
phase: 14-zram-swap-module
plan: 01
subsystem: infra
tags: [nix, zram, swap, btrfs, disko, nixos-modules]

# Dependency graph
requires:
  - phase: 09-btrfs-disko-layout
    provides: modules/system/disko.nix with btrfs/lvm layout options and isBtrfs/isLvm guards
provides:
  - nerv.disko.btrfs.zram.enable option (bool, default false) wired to zramSwap.enable
  - nerv.disko.btrfs.zram.memoryPercent option (int 1-100, default 50) wired to zramSwap.memoryPercent
  - Eval-time assertion preventing zram on LVM layout
affects: [15-starship-prompt-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lib.mkIf inside lib.mkIf isBtrfs for BTRFS-scoped optional features"
    - "lib.mkMerge with assertion guard as first entry for layout validation"
    - "zramSwap.algorithm = lib.mkForce to allow downstream override"

key-files:
  created: []
  modified:
    - modules/system/disko.nix

key-decisions:
  - "zramSwap block placed inside lib.mkIf isBtrfs (not lib.mkIf cfg.btrfs.zram.enable at top level) — double guard ensures no zram config emitted for LVM even if assertion is bypassed"
  - "lib.mkForce on algorithm = 'zstd' allows downstream override while hardcoding the v3.0 default"
  - "priority = 100 set to prefer zram over any other swap source (LVM has disk swap; BTRFS does not)"
  - "memoryMax intentionally omitted — avoids nixpkgs #435031 silent size truncation bug"
  - "nix flake check could not run on Arch Linux dev machine (nix not installed) — human verification required at Task 2 checkpoint"

patterns-established:
  - "BTRFS-only optional features: option in options.nerv.disko.btrfs.*, config inside lib.mkIf isBtrfs, guarded by lib.mkIf cfg.btrfs.*"

requirements-completed: [SWAP-01, SWAP-02, SWAP-03]

# Metrics
duration: 15min
completed: 2026-03-12
---

# Phase 14 Plan 01: zram Swap Module Summary

**zram compressed swap added to disko.nix with nerv.disko.btrfs.zram.{enable,memoryPercent} options, zstd-backed zramSwap wiring, and a hard eval assertion blocking LVM+zram misconfiguration**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-12T20:36:29Z
- **Completed:** 2026-03-12T20:51:00Z
- **Tasks:** 2 of 2
- **Files modified:** 1

## Accomplishments
- Extended `modules/system/disko.nix` with `btrfs.zram.enable` and `btrfs.zram.memoryPercent` options
- Wired options to NixOS built-in `zramSwap` module with zstd algorithm, priority=100, no memoryMax
- Added layout guard assertion as first `lib.mkMerge` entry — fires at eval when `zram.enable = true` on non-BTRFS layout

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend disko.nix with zram options and wired zramSwap config** - `90c8bec` (feat)
2. **Task 2: Verify zram implementation correctness** - checkpoint:human-verify (approved by user)

## Files Created/Modified
- `/home/demon/Developments/nerv.nixos/modules/system/disko.nix` - Added btrfs.zram options block, LVM assertion guard, and zramSwap config inside isBtrfs branch

## Decisions Made
- zramSwap block placed inside `lib.mkIf isBtrfs` (not only `lib.mkIf cfg.btrfs.zram.enable`) — double guard ensures correctness even without the assertion
- `lib.mkForce "zstd"` allows downstream override of algorithm while hardcoding v3.0 default
- `priority = 100` ensures zram is preferred over any other swap source on BTRFS hosts
- `memoryMax` intentionally omitted to avoid nixpkgs #435031 silent size truncation

## Deviations from Plan

None - plan executed exactly as written.

Note: `nix flake check` automated verification could not run on this Arch Linux dev machine (nix binary not installed). Human verification at Task 2 checkpoint covers this.

## Issues Encountered
- `nix flake check` verification could not run automatically — nix not installed on Arch Linux dev machine. Human verification checkpoint (Task 2) covers this.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- Plan 14-01 is complete; modules/system/disko.nix is stable and verified by user
- Runtime verification of SWAP-01 and SWAP-02 (swapon --show, zramctl, /proc/swaps) deferred to first production deploy with nerv.disko.btrfs.zram.enable = true
- Phase 15 (Starship prompt integration) is ready to begin

---
*Phase: 14-zram-swap-module*
*Completed: 2026-03-12*
