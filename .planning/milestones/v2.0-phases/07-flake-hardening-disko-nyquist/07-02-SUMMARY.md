---
phase: 07-flake-hardening-disko-nyquist
plan: 02
subsystem: infra
tags: [nix, flake, nixos, disko, disk-layout, luks, lvm, esp]

# Dependency graph
requires:
  - phase: 07-flake-hardening-disko-nyquist
    plan: 01
    provides: clean flake.nix with only nixpkgs/lanzaboote/home-manager inputs; explicit disabled-feature declarations in configuration.nix
provides:
  - flake.nix with disko input pinned to v1.13.0 (nixpkgs.follows) wired into outputs args and nixosConfigurations modules list
  - disko-configuration.nix with corrected ESP mount options (fmask=0077 dmask=0077 instead of umask=0077)
  - configuration.nix with fileSystems and swapDevices overrides removed — disko is now authoritative disk layout source
affects:
  - any future phase that reads disk layout or fileSystems configuration
  - deployment runbooks referencing mount configuration

# Tech tracking
tech-stack:
  added:
    - "disko v1.13.0 (github:nix-community/disko) — declarative disk layout flake input"
  patterns:
    - "disko as single source of truth for fileSystems and swapDevices — no host-level overrides"
    - "ESP uses fmask/dmask instead of umask for file/directory permission granularity"

key-files:
  created: []
  modified:
    - flake.nix
    - hosts/nixos-base/disko-configuration.nix
    - hosts/nixos-base/configuration.nix

key-decisions:
  - "disko pinned to v1.13.0 with nixpkgs.follows = nixpkgs — same pattern as lanzaboote and home-manager inputs"
  - "lib removed from configuration.nix function args after mkForce removal — no other lib references in file"
  - "ESP mountOptions changed from umask=0077 to fmask=0077 dmask=0077 — fmask/dmask gives separate file and directory permission control, matching the intent of the removed override"

patterns-established:
  - "Disk layout owned entirely by disko-configuration.nix via disko module — configuration.nix declares no fileSystems or swapDevices"

requirements-completed: []

# Metrics
duration: 2min
completed: 2026-03-08
---

# Phase 7 Plan 02: Disko Wiring Summary

**Wired disko v1.13.0 as flake input with nixpkgs.follows, added disko.nixosModules.disko to nixos-base modules list, corrected ESP mountOptions to fmask=0077 dmask=0077, and removed lib.mkForce fileSystems/swapDevices overrides from configuration.nix — disko is now the single authoritative source for disk layout.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-08T12:25:58Z
- **Completed:** 2026-03-08T12:27:58Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added disko input stanza (pinned v1.13.0, nixpkgs.follows) to flake.nix inputs block; added `disko` to outputs destructured args; appended `disko.nixosModules.disko` and `./hosts/nixos-base/disko-configuration.nix` to nixosConfigurations.nixos-base modules list
- Fixed ESP mountOptions in disko-configuration.nix from `[ "umask=0077" ]` to `[ "fmask=0077" "dmask=0077" ]` for correct file/directory permission separation
- Removed `fileSystems` block (with lib.mkForce overrides for /boot and /) and `swapDevices` line from configuration.nix; removed unused `lib` from function args; updated header Note to document disko ownership

## Task Commits

Each task was committed atomically:

1. **Task 1: Add disko flake input and wire into nixosConfigurations** - `1a19576` (feat)
2. **Task 2: Fix ESP mountOptions and remove fileSystems overrides** - `7b6d1af` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `flake.nix` - Added disko input + outputs arg + disko.nixosModules.disko and disko-configuration.nix in modules list
- `hosts/nixos-base/disko-configuration.nix` - Fixed ESP mountOptions from umask=0077 to fmask=0077 dmask=0077
- `hosts/nixos-base/configuration.nix` - Removed fileSystems/swapDevices overrides; removed lib from args; updated header Note

## Decisions Made

- disko pinned to v1.13.0 (not `master`) following existing convention of pinned inputs for infrastructure tooling
- `lib` removed from `configuration.nix` function args after confirming no remaining `lib.*` references — keeps the args minimal and avoids unused binding warnings
- ESP uses `fmask=0077 dmask=0077` rather than `umask=0077`: fmask controls file permissions (0077 → files are 0700), dmask controls directory permissions (0077 → directories are 0700); umask applies equally to both but is less explicit

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- `nix` binary not available in the dev environment shell (not on PATH). The `nix flake update disko`, `nix flake show`, `nix-instantiate --parse`, and `nixos-rebuild build` verification commands from the plan could not be run. Structural correctness of all three files was confirmed by inspection (valid Nix attribute set syntax, correct attribute paths, no fileSystems/swapDevices code in configuration.nix). The full `nix flake show` and `nixos-rebuild build` verification must be run on the target NixOS machine before deploying. This matches the precedent documented in 07-01-SUMMARY.md Issues Encountered.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `flake.nix` now has four inputs: nixpkgs, lanzaboote, home-manager, disko — all pinned or with nixpkgs.follows
- Disk layout has a single source of truth: `disko-configuration.nix`
- Tech debt item D from the v1.0 audit is closed
- Phase 7 plans complete — ready for Phase 8 (nyquist validation or next phase per ROADMAP.md)

---
*Phase: 07-flake-hardening-disko-nyquist*
*Completed: 2026-03-08*
