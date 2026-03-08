---
phase: 08-legacy-module-cleanup
plan: "01"
subsystem: infra
tags: [nixos, nix, modules, cleanup, dead-code]

# Dependency graph
requires:
  - phase: 02-services-reorganization
    provides: modules/services/ subtree with all structured service modules
  - phase: 03-system-modules-non-boot
    provides: modules/system/ subtree with all structured system modules
provides:
  - Clean modules/ root containing only default.nix, system/, and services/
  - Elimination of 9 dead flat *.nix files that created authorship ambiguity
affects:
  - future phases referencing modules/ structure

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - modules/ (9 files deleted — flat modules superseded by structured counterparts)

key-decisions:
  - "nix flake check --no-build skipped — nix binary unavailable on dev machine (non-NixOS); confirmed safe by auditing all import chains: modules/default.nix imports only ./system ./services ../home with no references to deleted flat files"

patterns-established:
  - "modules/ root holds only default.nix aggregator + subdirectories; no flat per-feature files"

requirements-completed:
  - dead-modules-cleanup

# Metrics
duration: 1min
completed: 2026-03-08
---

# Phase 8 Plan 01: Legacy Module Cleanup Summary

**Deleted 9 dead flat module files from modules/ root (openssh, pipewire, bluetooth, printing, zsh, kernel, security, nix, hardware) leaving only default.nix aggregator and system/services/ subdirectories**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-08T16:09:56Z
- **Completed:** 2026-03-08T16:10:59Z
- **Tasks:** 2
- **Files modified:** 9 deleted

## Accomplishments

- Removed 9 flat legacy *.nix files from modules/ root (705 lines of dead code eliminated)
- Confirmed modules/default.nix unchanged — still imports only ./system ./services ../home
- Verified no remaining references to deleted files anywhere in the codebase
- modules/ root now contains exactly: default.nix, system/, services/

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Delete 9 dead flat module files and verify** - `4fe43e9` (chore)

**Plan metadata:** _(docs commit pending)_

## Files Created/Modified

- `modules/bluetooth.nix` - DELETED (superseded by modules/services/bluetooth.nix)
- `modules/hardware.nix` - DELETED (superseded by modules/system/hardware.nix)
- `modules/kernel.nix` - DELETED (superseded by modules/system/kernel.nix)
- `modules/nix.nix` - DELETED (superseded by modules/system/nix.nix)
- `modules/openssh.nix` - DELETED (superseded by modules/services/openssh.nix)
- `modules/pipewire.nix` - DELETED (superseded by modules/services/pipewire.nix)
- `modules/printing.nix` - DELETED (superseded by modules/services/printing.nix)
- `modules/security.nix` - DELETED (superseded by modules/system/security.nix)
- `modules/zsh.nix` - DELETED (superseded by modules/services/zsh.nix)

## Decisions Made

- `nix flake check --no-build` could not be executed — `nix` binary is not present on this development machine (non-NixOS Linux). Confirmed deletion safety by auditing import chains: `modules/default.nix` imports only `./system ./services ../home`; grep across all *.nix files found zero references to the deleted flat module paths. Evaluation correctness verified by import-chain analysis rather than runtime check.

## Deviations from Plan

None — plan executed exactly as written, with the noted documentation of nix unavailability on dev machine (expected condition per project context).

## Issues Encountered

- `nix flake check --no-build` failed with "command not found: nix" — this is expected on the dev machine which is not a NixOS system. Import chain analysis confirmed deletion is safe: no *.nix file anywhere in the repo references the deleted paths.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- modules/ root is now clean — ready for Phase 08 Plans 02-04 (additional legacy cleanup tasks)
- No blockers

---
*Phase: 08-legacy-module-cleanup*
*Completed: 2026-03-08*
