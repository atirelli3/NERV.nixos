---
phase: 07-flake-hardening-disko-nyquist
plan: 01
subsystem: infra
tags: [nix, flake, nixos, impermanence, secureboot]

# Dependency graph
requires:
  - phase: 06-documentation-sweep
    provides: documentation headers and module comments already in place
provides:
  - flake.nix with impermanence input removed (inputs: nixpkgs, lanzaboote, home-manager only)
  - configuration.nix with explicit disabled-feature block (secureboot + impermanence = false)
affects:
  - 07-02-disko-wiring
  - any future phase that reads flake inputs or configuration.nix disabled-feature block

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Explicit disabled-feature declarations with descriptive comment header and inline rationale comments"
    - "flake.nix inputs and outputs signature kept in strict sync — no stale destructured args"

key-files:
  created: []
  modified:
    - flake.nix
    - hosts/nixos-base/configuration.nix

key-decisions:
  - "impermanence flake input removed — modules/system/impermanence.nix is self-contained using native NixOS fileSystems, no flake input needed"
  - "nerv.secureboot.enable = false and nerv.impermanence.enable = false explicitly declared so operators can see activation path without reading module source"
  - "nerv.zsh.enable = true left outside the disabled block — only disabled features grouped under the comment header"

patterns-established:
  - "Disabled features pattern: group all false-valued feature flags under a comment header with inline comments pointing to the enabling module and prerequisites"

requirements-completed: []

# Metrics
duration: 1min
completed: 2026-03-08
---

# Phase 7 Plan 01: Flake Hardening — Remove Impermanence Input

**Removed dead `impermanence` flake input from `flake.nix` and added explicit `nerv.secureboot.enable = false` / `nerv.impermanence.enable = false` declarations to `configuration.nix`, closing tech debt items B and C from the v1.0 audit.**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-08T11:42:27Z
- **Completed:** 2026-03-08T11:43:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Removed `impermanence` stanza from `flake.nix` inputs block (url + follows line) and from outputs function signature destructuring — inputs now contains exactly nixpkgs, lanzaboote, home-manager
- Added disabled-features comment header and two new explicit `= false` declarations to `hosts/nixos-base/configuration.nix` with inline comments pointing operators to the enabling module and hardware prerequisites
- Updated `configuration.nix` file header `Entry` line to list the two new options

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove impermanence flake input from flake.nix** - `887acbe` (feat)
2. **Task 2: Add explicit disabled-feature declarations to configuration.nix** - `6a7682e` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `flake.nix` - Removed impermanence input stanza and outputs arg; inputs block now has 3 entries
- `hosts/nixos-base/configuration.nix` - Added comment header + secureboot/impermanence disabled lines; updated Entry header

## Decisions Made

- impermanence flake input removed entirely: `modules/system/impermanence.nix` uses native NixOS `fileSystems` and `boot.tmp` options — it never consumed the flake input. Keeping the input was misleading and bloated the lock file.
- Explicit `= false` declarations chosen over omission: operators reading `configuration.nix` can now see exactly which features exist and where to enable them without reading module source code.
- `nerv.zsh.enable = true` stays on its own line outside the disabled block — the comment header applies only to disabled features.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- `nix` binary not available in the dev environment shell (not on PATH, no `/nix/store`). The `nix flake show` verification command from the plan could not be run. Structural correctness of `flake.nix` was confirmed by inspection (valid Nix attribute set syntax, three-input inputs block, outputs signature without `impermanence`). The full `nix flake show` verification must be run on the target NixOS machine before deploying.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `flake.nix` is clean: three inputs, no stale destructured args
- `configuration.nix` explicitly documents all module activation points
- Ready for Plan 02: disko wiring (add disko input, wire `fileSystems`/`swapDevices` overrides removal)

---
*Phase: 07-flake-hardening-disko-nyquist*
*Completed: 2026-03-08*

## Self-Check: PASSED

- flake.nix: FOUND
- hosts/nixos-base/configuration.nix: FOUND
- .planning/phases/07-flake-hardening-disko-nyquist/07-01-SUMMARY.md: FOUND
- Commit 887acbe: FOUND
- Commit 6a7682e: FOUND
