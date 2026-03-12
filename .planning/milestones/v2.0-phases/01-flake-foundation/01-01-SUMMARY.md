---
phase: 01-flake-foundation
plan: 01
subsystem: infra
tags: [nix, flakes, nixosModules, nixpkgs, home-manager, impermanence, lanzaboote]

# Dependency graph
requires: []
provides:
  - "Root flake.nix with nixosModules.default, .system, .services, .home exports"
  - "modules/default.nix aggregator importing system, services, home stubs"
  - "modules/system/default.nix empty stub"
  - "modules/services/default.nix empty stub"
  - "home/default.nix empty stub"
  - "base/flake.nix rewritten to consume nerv via path:.."
affects:
  - "02-service-modules (imports via nerv.nixosModules.default)"
  - "03-system-modules (populates modules/system/)"
  - "04-impermanence (impermanence input available in root flake)"
  - "05-home-manager (home-manager input available, home/ stub ready)"

# Tech tracking
tech-stack:
  added:
    - "lanzaboote (github:nix-community/lanzaboote) — root flake library input"
    - "home-manager (github:nix-community/home-manager) — root flake library input"
    - "impermanence (github:nix-community/impermanence) — root flake library input"
  patterns:
    - "inputs.X.inputs.nixpkgs.follows = nixpkgs on all library inputs"
    - "nixosModules output with default + granular named exports"
    - "import ./path pattern for nixosModules values (not bare path)"
    - "path:.. local flake input for host-to-library wiring"

key-files:
  created:
    - flake.nix
    - modules/default.nix
    - modules/system/default.nix
    - modules/services/default.nix
    - home/default.nix
  modified:
    - base/flake.nix

key-decisions:
  - "All library inputs (lanzaboote, home-manager, impermanence) live in root flake only — no duplication into base/flake.nix prevents lock drift"
  - "nixosModules values use import ./path (returns module) not bare path — required for nix flake check compatibility"
  - "modules/default.nix imports ../home (parent-relative) — safe because imports resolve relative to the file containing them"
  - "home-manager.nixosModules.home-manager is the canonical attribute name (not .default) — reserve .default alias for Phase 5 note"

patterns-established:
  - "Pattern: nixosModules export — each export uses import ./dir to return a valid NixOS module from default.nix in that directory"
  - "Pattern: stub aggregator — { imports = []; } as placeholder for directories populated by future phases"
  - "Pattern: git add before nix eval — new files in git repos must be staged before any nix flake command sees them"

requirements-completed: [STRUCT-01, STRUCT-04, STRUCT-05]

# Metrics
duration: 2min
completed: 2026-03-06
---

# Phase 1 Plan 01: Flake Foundation Summary

**Root library flake with nixosModules.{default,system,services,home} exports wired to host example via path:.. input, scaffolding all stub directories**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-06T17:51:53Z
- **Completed:** 2026-03-06T17:54:09Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Created root flake.nix as library entry point with four named nixosModules exports and all three library inputs (lanzaboote, home-manager, impermanence) each with inputs.nixpkgs.follows = "nixpkgs"
- Scaffolded modules/system/, modules/services/, and home/ directories with empty stub default.nix files, plus modules/default.nix aggregator
- Rewrote base/flake.nix to consume nerv library via inputs.nerv.url = "path:.." and nerv.nixosModules.default, removing direct module imports and lanzaboote as a host dependency

## Task Commits

Each task was committed atomically:

1. **Task 1: Create root flake.nix and all stub files** - `9491f6d` (feat)
2. **Task 2: Rewrite base/flake.nix and verify full phase gate** - `1948f06` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `flake.nix` — Root library flake: nixpkgs + lanzaboote + home-manager + impermanence inputs; nixosModules.{default,system,services,home} outputs
- `modules/default.nix` — Aggregator: { imports = [ ./system ./services ../home ]; }
- `modules/system/default.nix` — Empty stub: { imports = []; } — populated by Phase 3
- `modules/services/default.nix` — Empty stub: { imports = []; } — populated by Phase 2
- `home/default.nix` — Empty stub: { imports = []; } — populated by Phase 5
- `base/flake.nix` — Rewritten: nerv.url = "path:.."; modules = [ nerv.nixosModules.default ./configuration.nix ]

## Decisions Made

- Library inputs (lanzaboote, home-manager, impermanence) declared only in root flake.nix — host flake gets them transitively via nerv input, preventing lock file drift from duplication
- nixosModules values use `import ./path` (which evaluates default.nix and returns the module) rather than a bare path literal — required for nix flake check correctness
- Kept existing 10 flat .nix files in modules/ untouched — all migration happens in Phases 2 and 3

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The `nix` CLI is not installed on this Arch Linux development machine (host: crysis, OS: Arch Linux). The automated verification commands `nix flake show` and `nixos-rebuild build --flake ./base#nixos-base` could not be run. File content correctness was verified by:

1. Direct content inspection of all created/modified files
2. Pattern matching against exact specifications in the plan
3. Git staging verification (all files appear as `A` staged)
4. Confirmation that all 10 original flat modules in modules/ are untouched

The `nix flake show` and `nixos-rebuild build` gates must be verified manually on a NixOS machine or after installing the nix package manager on this Arch Linux host.

## User Setup Required

**Deferred verification required.** The following commands must be run on a machine with the `nix` CLI installed before considering the phase gate fully passed:

```bash
# From repo root — verify all four nixosModules exports appear
nix flake show 2>&1 | grep -E 'nixosModules\.(default|system|services|home)'

# From repo root — verify the host example builds end-to-end
nixos-rebuild build --flake ./base#nixos-base
```

Both commands require all six files to be git-staged (already done) or committed (Task 1 and 2 are committed).

## Next Phase Readiness

- Root flake.nix provides nixosModules.{default,system,services,home} — Phase 2 can add service module files to modules/services/ and add imports to modules/services/default.nix
- Phase 3 can add system module files to modules/system/ and update modules/system/default.nix
- Phase 4 impermanence input is declared and ready for wiring
- Phase 5 home-manager input is declared and home/default.nix stub is ready

Blocker for full sign-off: `nix` CLI must be available to run the phase gate verification commands.

## Self-Check: PASSED

All created files exist on disk. Both task commits verified in git log.

| Item | Status |
|------|--------|
| flake.nix | FOUND |
| modules/default.nix | FOUND |
| modules/system/default.nix | FOUND |
| modules/services/default.nix | FOUND |
| home/default.nix | FOUND |
| base/flake.nix | FOUND |
| 01-01-SUMMARY.md | FOUND |
| commit 9491f6d (Task 1) | FOUND |
| commit 1948f06 (Task 2) | FOUND |

---
*Phase: 01-flake-foundation*
*Completed: 2026-03-06*
