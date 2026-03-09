---
phase: 09-btrfs-disko-layout
plan: "01"
subsystem: infra
tags: [nix, disko, btrfs, lvm, luks, disk-layout]

# Dependency graph
requires:
  - phase: 08-legacy-module-cleanup
    provides: cleaned module structure with impermanence.nix and disko.nix baseline
provides:
  - nerv.disko.layout enum option (btrfs | lvm, no default)
  - BTRFS branch: 6 subvolumes with correct mount options and @root-blank baseline
  - LVM branch: swap + store + persist LVs under lib.mkIf isLvm
  - sharedEsp and sharedLuksOuter let bindings for DRY disk config
affects:
  - 10-initrd-btrfs-rollback
  - 11-impermanence-btrfs-mode
  - 12-profile-wiring-documentation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lib.mkMerge with lib.mkIf isBtrfs / isLvm for conditional disk layout branching"
    - "Let bindings for shared disko partition config (sharedEsp, sharedLuksOuter)"
    - "No default on enum option — forces explicit per-host declaration (nerv.hostname pattern)"

key-files:
  created:
    - modules/system/disko.nix
  modified: []

key-decisions:
  - "nerv.disko.layout has no default — forces explicit declaration per host, consistent with nerv.hostname and nerv.hardware.cpu"
  - "sharedEsp and sharedLuksOuter factored as let bindings — both BTRFS and LVM branches share identical ESP and LUKS wrapper"
  - "@root-blank declared as empty attrset with no mountpoint — Phase 10 will use it as a rollback snapshot baseline"
  - "No swap in BTRFS branch — BTRFS CoW is incompatible with swap files; emit nothing in btrfs branch"
  - "All impermanence.mode references removed — disko.nix now depends only on cfg.layout"
  - "lvm sub-namespace replaces flat swapSize/rootSize/storeSize/persistSize — cleaner API, rootSize removed (not needed in BTRFS layout)"

patterns-established:
  - "Pattern: isBtrfs / isLvm let bindings derived from cfg.layout for conditional config branches"
  - "Pattern: sharedEsp / sharedLuksOuter let bindings to avoid repeating ESP and LUKS partition config"

requirements-completed: [DISKO-01, DISKO-02, DISKO-03]

# Metrics
duration: 2min
completed: "2026-03-09"
---

# Phase 9 Plan 01: Disko Layout Option and BTRFS/LVM Branches Summary

**nerv.disko.layout enum (btrfs|lvm, no default) with BTRFS 6-subvolume branch and LVM swap/store/persist branch, both sharing factored ESP and LUKS wrapper let bindings**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-09T23:42:20Z
- **Completed:** 2026-03-09T23:43:48Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Rewrote modules/system/disko.nix replacing impermanence.mode-conditional LVM layout with nerv.disko.layout enum
- BTRFS branch: 6 subvolumes (@, @root-blank with no mountpoint, @home, @nix, @persist, @log) each with compress=zstd:3 + noatime + space_cache=v2
- LVM branch: swap, store, persist LVs under lib.mkIf isLvm — no LVM outside that guard
- Factored sharedEsp and sharedLuksOuter as let bindings — both branches share identical outer disk structure
- Removed all config.nerv.impermanence.mode references from disko.nix

## Task Commits

1. **Task 1: Rewrite disko.nix with layout option and BTRFS branch** - `76758ac` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `modules/system/disko.nix` — Complete rewrite: nerv.disko.layout enum + BTRFS branch (6 subvolumes) + LVM branch (3 LVs) + shared let bindings

## Decisions Made

- `nerv.disko.layout` has no default — forces explicit declaration per host, consistent with the nerv.hostname / nerv.hardware.cpu pattern already established
- `sharedEsp` and `sharedLuksOuter` factored as let bindings so both BTRFS and LVM branches share identical outer disk config without duplication
- `@root-blank` declared as empty attrset `= {}` with no mountpoint — Phase 10 will create a read-only snapshot at this subvolume path as the rollback baseline
- Old `nerv.disko.swapSize`, `nerv.disko.rootSize` removed; LVM sizes moved to `nerv.disko.lvm.*` sub-namespace; rootSize has no equivalent in BTRFS layout (no root LV)
- All `config.nerv.impermanence.mode` references removed — disko.nix is now fully self-contained, depending only on `cfg.layout`

## Deviations from Plan

None — plan executed exactly as written.

Note: `nix-instantiate --parse` not available on dev machine (consistent with Phase 8 precedent). All done criteria verified manually:
- `grep -c 'space_cache=v2'` returns 5
- `"/@root-blank" = {}` with no mountpoint key
- No `isFullMode` or `impermanence.mode` references
- `lvm_vg` and `"swap"` type only inside `lib.mkIf isLvm` block
- `lib.types.enum [ "btrfs" "lvm" ]` present with no default

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Self-Check: PASSED

- `modules/system/disko.nix` — FOUND
- `09-01-SUMMARY.md` — FOUND
- Commit `76758ac` — FOUND

## Next Phase Readiness

- `modules/system/disko.nix` provides the core option interface for all Phase 9-12 downstream work
- Phase 10 (initrd BTRFS rollback service) can now reference `nerv.disko.layout == "btrfs"` for conditional rollback service activation
- Phase 11 (impermanence BTRFS mode) can reference `nerv.disko.layout` for btrfs-specific persistence wiring
- Phase 12 (profile wiring and documentation) needs to set `nerv.disko.layout = "btrfs"` in desktop/laptop profiles and `"lvm"` in server profile
- Hosts must declare `nerv.disko.layout` explicitly — eval will error without it (by design)

---
*Phase: 09-btrfs-disko-layout*
*Completed: 2026-03-09*
