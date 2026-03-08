---
phase: 01-flake-foundation
plan: 02
subsystem: infra
tags: [nixos, flake, hosts, disko, directory-structure]

# Dependency graph
requires: []
provides:
  - hosts/nixos-base/ directory with all three config files (configuration.nix, disko-configuration.nix, hardware-configuration.nix)
  - flake.nix nixosConfigurations.nixos-base pointing to ./hosts/nixos-base/configuration.nix
  - base/ directory removed from repo
affects:
  - All future phases that reference hosts/nixos-base/ for host-specific configuration

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "hosts/<hostname>/ convention for all future host configs"
    - "hardware-configuration.nix tracked in repo under hosts/<hostname>/, not under /etc/nixos"

key-files:
  created:
    - hosts/nixos-base/configuration.nix
    - hosts/nixos-base/disko-configuration.nix
    - hosts/nixos-base/hardware-configuration.nix
  modified:
    - flake.nix

key-decisions:
  - "hardware-configuration.nix tracked in repo as a placeholder on dev machine; replaced with real nixos-generate-config output on NixOS machine"
  - "base/flake.nix removed — nixosConfigurations live in root flake.nix using self references, not sub-flake (pure eval forbids absolute store paths)"

patterns-established:
  - "hosts/<hostname>/: three-file pattern — configuration.nix, disko-configuration.nix, hardware-configuration.nix"

requirements-completed: [STRUCT-01, STRUCT-04, STRUCT-05]

# Metrics
duration: 1min
completed: 2026-03-06
---

# Phase 1 Plan 02: Host Directory Rename Summary

**NixOS host config migrated from base/ to hosts/nixos-base/ with hardware-configuration.nix placeholder, establishing the three-file hosts/<hostname>/ convention for all future phases.**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-06T21:32:00Z
- **Completed:** 2026-03-06T21:33:01Z
- **Tasks:** 2
- **Files modified:** 4 (3 moved, 1 updated, 1 created)

## Accomplishments
- Moved configuration.nix and disko-configuration.nix from base/ to hosts/nixos-base/ using git mv (preserving history)
- Removed base/flake.nix (superseded by root flake.nix nixosConfigurations with self references)
- Updated flake.nix nixosConfigurations.nixos-base to reference ./hosts/nixos-base/configuration.nix
- Created hardware-configuration.nix placeholder (dev machine — /etc/nixos/ does not exist on Arch Linux)
- Confirmed base/ directory is fully removed from the repo

## Task Commits

Each task was committed atomically:

1. **Task 1: Move base/ to hosts/nixos-base/ and update flake.nix** - `56b9402` (feat)
2. **Task 2: Add hardware-configuration.nix placeholder** - `07dd4be` (feat)

## Files Created/Modified
- `hosts/nixos-base/configuration.nix` - Host machine NixOS config (moved from base/, history preserved)
- `hosts/nixos-base/disko-configuration.nix` - Disko disk layout (moved from base/, history preserved)
- `hosts/nixos-base/hardware-configuration.nix` - Placeholder; replace with nixos-generate-config output on NixOS machine
- `flake.nix` - Updated nixosConfigurations.nixos-base module path from ./base/configuration.nix to ./hosts/nixos-base/configuration.nix

## Decisions Made
- hardware-configuration.nix tracked in repo under hosts/nixos-base/ as a placeholder on dev machine; must be replaced with real output of `nixos-generate-config --show-hardware-config` on the NixOS machine.
- base/flake.nix was removed — it defined a sub-flake nixosConfigurations that is superseded by the root flake.nix approach (path:.. fails when /etc/nerv is a nix store symlink under pure eval).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- hosts/nixos-base/ is correctly structured for all subsequent phases
- flake.nix nixosConfigurations references the canonical path
- hardware-configuration.nix placeholder must be replaced with real hardware config when deploying on the NixOS machine
- No blockers for Phase 1 Plan 03+

---
*Phase: 01-flake-foundation*
*Completed: 2026-03-06*
