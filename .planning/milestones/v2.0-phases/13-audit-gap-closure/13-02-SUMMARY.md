---
phase: 13-audit-gap-closure
plan: "02"
subsystem: documentation
tags: [btrfs, impermanence, install-procedure, rollback, readme]

# Dependency graph
requires:
  - phase: 10-initrd-btrfs-rollback-service
    provides: rollback service implementation that @root-blank enables at runtime
provides:
  - "README.md Section A BTRFS install walkthrough extended from 13 to 14 steps with mandatory @root-blank snapshot step"
affects:
  - 14-documentation-sweep
  - any future phase touching install procedures

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Install procedure documentation travels with the code that declares the feature (BOOT-02 pattern)"

key-files:
  created: []
  modified:
    - README.md

key-decisions:
  - "Step comment placement: new step 7 inserted between disko provision (step 6) and repo copy (now step 8) — sequential dependency preserved"
  - "Inline comment uses exact wording from PROF-04: Required: @root-blank is the clean-root template — initrd deletes @ and restores from this on every boot"

patterns-established:
  - "Install procedure steps use numbered comments inside a bash code block; renumbering must be done atomically to prevent duplicate or skipped numbers"

requirements-completed: [PROF-04, BOOT-02]

# Metrics
duration: 1min
completed: 2026-03-12
---

# Phase 13 Plan 02: Audit Gap Closure — @root-blank Snapshot Step Summary

**README.md Section A extended from 13 to 14 steps: mandatory `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank` inserted as step 7 with inline comment explaining the clean-root template requirement.**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-12T18:45:26Z
- **Completed:** 2026-03-12T18:46:19Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments

- Inserted new step 7 in Section A: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`
- Added required inline comment: `# Required: @root-blank is the clean-root template — initrd deletes @ and restores from this on every boot.`
- Renumbered old steps 7–13 to 8–14 with no duplicate or skipped numbers
- Section A now contains 14 steps numbered 1–14 consecutively
- Section B (LVM walkthrough), Section C, and Section D are unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Insert @root-blank snapshot step and renumber README Section A steps 7–13** - `3459483` (docs)

**Plan metadata:** `(pending final commit)`

## Files Created/Modified

- `/home/demon/Developments/nerv.nixos/README.md` - Section A extended from 13 to 14 steps; @root-blank snapshot step inserted as step 7

## Decisions Made

- Step inserted between step 6 (disko provision) and what was step 7 (copy repo) — this is the only correct position; @root-blank must exist before nixos-install so the rollback service finds it on first boot
- Inline comment wording preserved exactly as specified in PROF-04 requirement

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PROF-04 and BOOT-02 requirements satisfied: install procedure now documents the mandatory post-disko @root-blank snapshot step
- The rollback service (implemented in Phase 10) is now usable by operators following the README
- No blockers for subsequent plans in Phase 13

---
*Phase: 13-audit-gap-closure*
*Completed: 2026-03-12*
