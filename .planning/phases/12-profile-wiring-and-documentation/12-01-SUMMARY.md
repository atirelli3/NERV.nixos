---
phase: 12-profile-wiring-and-documentation
plan: 01
subsystem: infra
tags: [nix, flake, profiles, disko, impermanence, btrfs, lvm]

# Dependency graph
requires:
  - phase: 11-impermanence-btrfs-mode
    provides: nerv.impermanence.mode enum [btrfs, full] — replaces invalid "minimal"
  - phase: 9-btrfs-disko-layout
    provides: nerv.disko.layout enum [btrfs, lvm] — new option wired in profiles
provides:
  - hostProfile with nerv.disko.layout = "btrfs" and nerv.impermanence.mode = "btrfs"
  - serverProfile with nerv.disko.layout = "lvm" and nerv.impermanence.mode = "full"
  - vmProfile and nixosConfigurations.vm removed; flake has exactly two nixosConfigurations
affects: [any consumer of flake.nix profiles, PROF-01, PROF-02, install procedure docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Profile-level layout/mode declaration — nerv.disko.layout and nerv.impermanence.mode set in profile attrset, not in hosts/configuration.nix"
    - "Alignment convention col 26 for = sign across all profile attributes"

key-files:
  created: []
  modified:
    - flake.nix

key-decisions:
  - "nerv.disko.layout = \"btrfs\" added as first attribute in hostProfile — ordering matches plan spec (layout before openssh)"
  - "nerv.disko.layout = \"lvm\" added as first attribute in serverProfile — same ordering convention"
  - "vmProfile deleted with no stub or replacement comment — clean removal per CONTEXT.md locked decision"
  - "nixosConfigurations.vm deleted with no stub — flake outputs.nixosConfigurations is exactly host + server"

patterns-established:
  - "Profile-level layout declaration: nerv.disko.layout must be the first attribute in any profile block"
  - "Enum alignment: profile attributes use col 26 for = sign (attribute name + padding)"

requirements-completed: [PROF-01, PROF-02]

# Metrics
duration: 1min
completed: 2026-03-10
---

# Phase 12 Plan 01: Profile Wiring and Documentation Summary

**flake.nix profiles updated: hostProfile gains btrfs layout + btrfs mode; serverProfile gains lvm layout; vmProfile and nixosConfigurations.vm deleted entirely**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-10T10:02:07Z
- **Completed:** 2026-03-10T10:03:03Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- hostProfile declares nerv.disko.layout = "btrfs" and nerv.impermanence.mode = "btrfs" — fixes the build-breaking "minimal" enum value and wires Phase 9 layout option (PROF-01)
- serverProfile declares nerv.disko.layout = "lvm" alongside the existing nerv.impermanence.mode = "full" (PROF-02)
- vmProfile let-binding and nixosConfigurations.vm removed cleanly — no stubs; flake outputs.nixosConfigurations contains exactly host and server

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite flake.nix profiles — add layout/mode, remove vmProfile** - `8709893` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `flake.nix` — hostProfile and serverProfile updated with nerv.disko.layout; vmProfile let-binding and nixosConfigurations.vm block deleted

## Decisions Made

- nerv.disko.layout placed as the first attribute in each profile block, consistent with the plan spec and col-26 alignment convention
- vmProfile deleted entirely with no stub or replacement comment, per CONTEXT.md locked decision
- nixosConfigurations.vm deleted entirely; flake now exposes exactly two configurations: host and server

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PROF-01 and PROF-02 satisfied: all profiles aligned with Phase 9 (disko layout) and Phase 11 (impermanence mode) enum values
- "minimal" string absent from flake.nix — evaluation error against Phase 11 enum is resolved
- Ready for Phase 12 Plan 02 (documentation tasks, if any)

---
*Phase: 12-profile-wiring-and-documentation*
*Completed: 2026-03-10*
