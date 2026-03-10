---
phase: 12-profile-wiring-and-documentation
plan: "03"
subsystem: documentation
tags: [readme, btrfs, impermanence, disko, profiles, install-procedure]

# Dependency graph
requires:
  - phase: 12-profile-wiring-and-documentation
    provides: "Phase 12-01 rewrote flake.nix profiles (removed vm, added host/server with btrfs/lvm layout); 12-02 added Profiles cross-references to module headers"
  - phase: 09-btrfs-disko-layout
    provides: "modules/system/disko.nix with btrfs/lvm branches and @root-blank subvolume"
  - phase: 10-initrd-btrfs-rollback-service
    provides: "@root-blank snapshot requirement and rollback service semantics"
  - phase: 11-impermanence-btrfs-mode
    provides: "nerv.impermanence.mode enum as [btrfs, full] with no default"
provides:
  - "README.md Section B: complete BTRFS install walkthrough with mandatory @root-blank snapshot step"
  - "README.md Profiles table: two rows only (host/server), vm row removed"
  - "README.md Repository Layout: modules/system/disko.nix added, hosts/disko-configuration.nix removed"
  - "README.md impermanence Module Reference: mode enum updated to btrfs|full"
  - "README.md impermanence bullet: replaced 'minimal' with 'btrfs' rollback description"
affects: [operators-installing-btrfs-hosts, future-documentation-updates]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Install procedure documentation travels with the code: @root-blank install note in disko.nix header, operator-facing walkthrough in README Section B"

key-files:
  created: []
  modified:
    - README.md

key-decisions:
  - "Section A (LVM/disko-configuration.nix path) left unchanged — plan explicitly forbids modification; Section B is new BTRFS-specific section"
  - "boot.nix Module Reference updated to reference modules/system/disko.nix — removes stale hosts/disko-configuration.nix reference from prose outside Section A"
  - "impermanence.nix module note updated to cover both btrfs and full modes (not only server/full)"

patterns-established:
  - "Profile install sections are profile-specific: Section A for LVM, Section B for BTRFS — each has its own disko invocation and any mandatory post-disko steps"

requirements-completed:
  - PROF-04

# Metrics
duration: 10min
completed: 2026-03-10
---

# Phase 12 Plan 03: README BTRFS Install Section and Documentation Updates Summary

**README updated with BTRFS install walkthrough (Section B), @root-blank mandatory step, two-row Profiles table, and corrected disko/impermanence documentation across Repository Layout and Module Reference**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-10T10:00:00Z
- **Completed:** 2026-03-10T10:05:37Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Added Section B: full BTRFS install walkthrough with mandatory @root-blank snapshot as step 5 (before nixos-install), with warning callout explaining why it cannot be skipped
- Removed vm row from Profiles table; updated host description to BTRFS impermanence, server to LVM layout + full impermanence
- Re-lettered former Section B to C and Section C to D
- Updated Repository Layout: removed hosts/disko-configuration.nix, added modules/system/disko.nix, updated boot.nix and impermanence.nix descriptions
- Updated impermanence.nix Module Reference table: mode enum is now "btrfs"|"full" (was "minimal"|"full"), mode default is **required**
- Added BTRFS mode persists description; updated module note to cover both host and server profiles
- Replaced "minimal" mode reference in "What NERV provides" bullet with "btrfs" rollback description

## Task Commits

Each task was committed atomically:

1. **Task 1: Insert BTRFS install section; re-letter B→C and C→D; update Profiles table and impermanence description** - `1413041` (docs)
2. **Task 2: Update Repository Layout section and impermanence.nix Module Reference table** - `a07e11e` (docs)

## Files Created/Modified

- `/Users/nemesixsrl/Developemnt/NERV.nixos/README.md` - Added BTRFS Section B, re-lettered sections, removed vm profile, updated Repository Layout tree, updated impermanence Module Reference

## Decisions Made

- Section A left completely unchanged per plan constraint — it references `hosts/disko-configuration.nix` which is the LVM install path and remains valid
- boot.nix Module Reference prose updated to remove stale `hosts/disko-configuration.nix` reference (outside Section A, this was a stale cross-reference)
- impermanence module note broadened to cover both btrfs (host) and full (server) modes

## Deviations from Plan

None - plan executed exactly as written. One interpretive decision: Task 2 automated verification check `! grep -q 'hosts/disko-configuration.nix'` was intentionally not fully satisfiable because Section A (which the plan explicitly forbids changing) contains three references to that path. The stale reference in the boot.nix Module Reference prose was fixed; Section A references remain per the `<interfaces>` constraint.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 12 (Profile Wiring and Documentation) is now complete: all three plans executed
- PROF-01, PROF-02 (Plan 12-01), PROF-03 (Plan 12-02), PROF-04 (Plan 12-03) all satisfied
- README.md accurately reflects the current v2.0 architecture (BTRFS disko, rollback service, btrfs impermanence mode)
- No blockers for future work

## Self-Check: PASSED

- FOUND: README.md
- FOUND: .planning/phases/12-profile-wiring-and-documentation/12-03-SUMMARY.md
- FOUND: commit 1413041 (Task 1)
- FOUND: commit a07e11e (Task 2)

---
*Phase: 12-profile-wiring-and-documentation*
*Completed: 2026-03-10*
