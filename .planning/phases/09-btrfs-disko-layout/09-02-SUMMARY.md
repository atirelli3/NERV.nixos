---
phase: 09-btrfs-disko-layout
plan: "02"
subsystem: infra
tags: [nix, disko, btrfs, lvm, disk-layout, configuration]

# Dependency graph
requires:
  - phase: 09-btrfs-disko-layout
    provides: nerv.disko.layout enum option and nerv.disko.lvm.* sub-namespace in modules/system/disko.nix (Plan 01)
provides:
  - hosts/configuration.nix updated with new nerv.disko.layout + nerv.disko.lvm.* API
  - No broken option references — flake evaluation can proceed without undefined option errors
affects:
  - 10-initrd-btrfs-rollback
  - 11-impermanence-btrfs-mode
  - 12-profile-wiring-documentation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PLACEHOLDER as intentionally invalid enum value — forces operator to set a real layout before boot (same forcing pattern as nerv.hostname)"

key-files:
  created: []
  modified:
    - hosts/configuration.nix

key-decisions:
  - "nerv.disko.layout = \"PLACEHOLDER\" is intentionally invalid — nix eval will error if layout is not set to \"btrfs\" or \"lvm\" before build"
  - "nerv.disko.lvm.* declared unconditionally in configuration.nix; they are ignored by the module when layout = \"btrfs\""

patterns-established:
  - "Pattern: caller declarations mirror module API exactly — no intermediate translation layer"

requirements-completed: [DISKO-01, DISKO-02, DISKO-03]

# Metrics
duration: 1min
completed: "2026-03-09"
---

# Phase 9 Plan 02: Update hosts/configuration.nix to New nerv.disko.* API Summary

**hosts/configuration.nix updated: flat nerv.disko.{swapSize,rootSize,storeSize,persistSize} replaced with nerv.disko.layout + nerv.disko.lvm.{swapSize,storeSize,persistSize}, eliminating broken option references**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-09T23:45:32Z
- **Completed:** 2026-03-09T23:46:42Z
- **Tasks:** 2 of 2
- **Files modified:** 1

## Accomplishments

- Replaced four old flat nerv.disko.* options with new layout + lvm.* API
- Added nerv.disko.layout = "PLACEHOLDER" with explanatory comment (intentionally invalid — forces explicit declaration)
- Added nerv.disko.lvm.{swapSize,storeSize,persistSize} under LVM-only comment
- Updated header Entry comment to list nerv.disko.layout, nerv.disko.lvm.*

## Task Commits

1. **Task 1: Update hosts/configuration.nix to new nerv.disko.* API** - `5641b6c` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `hosts/configuration.nix` — Replaced old flat disko options with nerv.disko.layout and nerv.disko.lvm.* sub-namespace; updated header Entry comment

## Decisions Made

- `nerv.disko.layout = "PLACEHOLDER"` is intentionally an invalid enum value — the module system will error at eval time if the operator tries to build without replacing it with "btrfs" or "lvm". This is the same forcing pattern used by nerv.hostname and nerv.hardware.cpu.
- `nerv.disko.lvm.*` options are declared unconditionally in configuration.nix; they only have effect when layout = "lvm". Declaring them unconditionally keeps the file self-documenting and avoids conditional syntax at the caller level.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

`nix-instantiate` and `nix` are not available on this dev machine (consistent with Phase 9 Plan 01 precedent). Done criteria verified manually:

- `grep` confirms zero references to `nerv.disko.swapSize`, `nerv.disko.rootSize`, `nerv.disko.storeSize`, `nerv.disko.persistSize` (flat old names)
- `grep` confirms `nerv.disko.layout = "PLACEHOLDER"` present on line 43
- `grep` confirms three `nerv.disko.lvm.*` assignments (swapSize, storeSize, persistSize) on lines 46-48
- Header Entry comment on lines 7-9 lists `nerv.disko.layout, nerv.disko.lvm.*`

## User Setup Required

None — no external service configuration required.

## Self-Check: PASSED

- `hosts/configuration.nix` — FOUND (updated)
- `09-02-SUMMARY.md` — FOUND (this file)
- Commit `5641b6c` — verified via git log

## Next Phase Readiness

- `hosts/configuration.nix` and `modules/system/disko.nix` are now in sync — no undefined option references
- Phase 10 (initrd BTRFS rollback) can proceed — disko module is fully wired
- Operators must replace `nerv.disko.layout = "PLACEHOLDER"` with "btrfs" or "lvm" before building for a real machine

---
*Phase: 09-btrfs-disko-layout*
*Completed: 2026-03-09*
