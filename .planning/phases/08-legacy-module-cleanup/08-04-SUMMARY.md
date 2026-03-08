---
phase: 08-legacy-module-cleanup
plan: 04
subsystem: infra
tags: [git, github, migration, nerv-nixos, planning]

# Dependency graph
requires:
  - phase: 08-legacy-module-cleanup
    provides: "08-01, 08-02, 08-03 completed — refined structure in test-nerv.nixos"
provides:
  - "NERV.nixos repo at git@github.com:atirelli3/NERV.nixos.git with complete v1.0 NixOS module library"
  - "Full .planning/ context copied to NERV.nixos for continued development"
  - "test-nerv.nixos reset to baseline commit cab4126e — development history traceable"
affects:
  - "NERV.nixos — primary public repo for all future development"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Git repo migration: rsync copy of tracked files + git push to fresh target repo"
    - "Planning context portability: .planning/ committed alongside source code"

key-files:
  created:
    - "/tmp/nerv-nixos/flake.nix"
    - "/tmp/nerv-nixos/home/default.nix"
    - "/tmp/nerv-nixos/hosts/configuration.nix"
    - "/tmp/nerv-nixos/hosts/disko-configuration.nix"
    - "/tmp/nerv-nixos/hosts/hardware-configuration.nix"
    - "/tmp/nerv-nixos/modules/default.nix"
    - "/tmp/nerv-nixos/modules/services/*.nix (5 files)"
    - "/tmp/nerv-nixos/modules/system/*.nix (8 files)"
    - "/tmp/nerv-nixos/.planning/ (92 files)"
  modified: []

key-decisions:
  - "User addition: copy .planning/ to NERV.nixos before reset — preserves full project context (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, all phase plans and summaries) for continued development planning"
  - "SUMMARY.md written to /tmp/nerv-nixos/.planning/ (not test-nerv.nixos) — test repo was reset to cab4126e, which removes the .planning/ directory from HEAD"

patterns-established:
  - "Graduation pattern: develop in test repo, push refined structure to public repo, reset test repo to baseline"

requirements-completed:
  - IMPL-06

# Metrics
duration: 15min
completed: 2026-03-08
---

# Phase 8 Plan 04: Legacy Module Cleanup — Repo Migration Summary

**Complete NERV.nixos v1.0 release: modules/services + modules/system with nerv.* options API, three inline profiles (host/server/vm), and full .planning/ context pushed to GitHub; test-nerv.nixos reset to baseline commit cab4126e**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-08T16:16:50Z
- **Completed:** 2026-03-08T16:35:00Z
- **Tasks:** 3 (Task 1 in prior session, Task 2 checkpoint confirmed, Task 3 + addition in this session)
- **Files modified:** 92 files added to NERV.nixos (modules + .planning/)

## Accomplishments

- Copied all refined NixOS module work (home/, hosts/, modules/, flake.nix) from test-nerv.nixos to NERV.nixos and pushed as the initial v1.0 release commit (`2c58d63`)
- Copied entire .planning/ directory (92 files: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, all phase plans/summaries, codebase analysis, research) to NERV.nixos and pushed as a separate commit (`d18d3f2`), preserving full project context for continued development
- Reset test-nerv.nixos to baseline commit `cab4126e` (HEAD: "base system") — development journey traceable, public repo clean

## Task Commits

Tasks executed across two sessions:

1. **Task 1: Clone NERV.nixos and copy refined structure** - `2c58d63` on NERV.nixos (feat: initial NERV.nixos release — v1.0)
2. **Task 2: Checkpoint human-verify** - User confirmed push and approved reset with addition
3. **User addition: copy .planning/ to NERV.nixos** - `d18d3f2` on NERV.nixos (docs: add project planning context)
4. **Task 3: Reset test-nerv.nixos** - `cab4126e` is now HEAD (git reset --hard, no commit created)

## Files Created/Modified

NERV.nixos repo (at `/tmp/nerv-nixos` and pushed to `git@github.com:atirelli3/NERV.nixos.git`):
- `flake.nix` — Root flake with impermanence input, three inline profiles (hostProfile, serverProfile, vmProfile), nixosConfigurations (host, server, vm)
- `home/default.nix` — Home Manager wiring module with nerv.home.users option
- `hosts/configuration.nix` — Identity-only: hostname, primaryUser, hardware.cpu/gpu, locale, disk device, stateVersion
- `hosts/disko-configuration.nix` — Server disk layout (server profile, full impermanence)
- `hosts/hardware-configuration.nix` — Placeholder from hosts/nixos-base/
- `modules/default.nix` — Root aggregator
- `modules/services/default.nix` + 5 service modules (openssh, pipewire, bluetooth, printing, zsh)
- `modules/system/default.nix` + 8 system modules (boot, hardware, identity, impermanence, kernel, nix, secureboot, security)
- `.planning/` — 92 files: full GSD planning context

## Decisions Made

- User requested .planning/ be copied to NERV.nixos before reset — this preserves PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, and all phase plans/summaries (01-08) so development can continue in the public repo using the same GSD workflow
- SUMMARY.md written to `/tmp/nerv-nixos/.planning/phases/08-legacy-module-cleanup/08-04-SUMMARY.md` (the NERV.nixos copy) rather than test-nerv.nixos, since the reset removed the .planning/ directory from the test repo HEAD

## Deviations from Plan

### Auto-fixed Issues

**1. [User Addition] Copy .planning/ to NERV.nixos before reset**
- **Found during:** Between Task 2 (checkpoint) and Task 3 (reset)
- **Issue:** Plan did not include copying .planning/ — user specified this addition at checkpoint approval
- **Fix:** `cp -r /home/demon/Developments/test-nerv.nixos/.planning /tmp/nerv-nixos/` followed by `git add .planning/ && git commit && git push`
- **Files modified:** 92 files added to NERV.nixos under .planning/
- **Commit:** `d18d3f2` on NERV.nixos

---

**Total deviations:** 1 (user-directed addition, not auto-fix)
**Impact on plan:** Preserves full project planning context for NERV.nixos. No scope creep — explicit user instruction.

## Issues Encountered

None — SSH auth was already in place from Task 1. Both pushes and the reset completed without error.

## User Setup Required

None - no external service configuration required beyond SSH key already configured.

## Next Phase Readiness

Phase 8 is complete. All 4 plans executed:
- 08-01: Deleted 9 dead flat modules
- 08-02: Extended impermanence.nix with mode option, wrote server disko-configuration.nix
- 08-03: Rewrote flake.nix with inline profiles, created identity-only hosts/configuration.nix
- 08-04: Migrated to NERV.nixos, copied .planning/, reset test repo

The NERV.nixos repo at `git@github.com:atirelli3/NERV.nixos.git` is the canonical home for all future development. The .planning/ context is present in NERV.nixos for GSD continuation.

Remaining work (from ROADMAP.md, Phase 5 not yet executed):
- Phase 5: Home Manager Skeleton — wire home-manager.nixosModules.home-manager, implement nerv.home.* module (1 plan)

---
*Phase: 08-legacy-module-cleanup*
*Completed: 2026-03-08*
