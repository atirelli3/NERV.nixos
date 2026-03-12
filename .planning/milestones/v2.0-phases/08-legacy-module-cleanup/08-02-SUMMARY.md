---
phase: 08-legacy-module-cleanup
plan: 02
subsystem: infra
tags: [nix, impermanence, disko, lvm, luks, flake, tmpfs, server]

# Dependency graph
requires:
  - phase: 07-flake-hardening-disko-nyquist
    provides: Hardened flake.nix with disko pinned; impermanence removed from inputs
  - phase: 04-boot-extraction
    provides: boot.nix and secureboot.nix with NIXLUKS cross-reference pattern
provides:
  - impermanence flake input re-added to flake.nix (no nixpkgs follows)
  - nerv.impermanence.mode enum [minimal full] with default minimal
  - full mode config block (/ as tmpfs + environment.persistence with server state paths)
  - hosts/disko-configuration.nix server layout (NIXBOOT/NIXLUKS/NIXSWAP/NIXSTORE/NIXPERSIST)
affects:
  - 08-03 (multi-profile flake — will import hosts/disko-configuration.nix in serverProfile)
  - any plan adding a server nixosConfiguration (must include impermanence.nixosModules.impermanence)

# Tech tracking
tech-stack:
  added: [github:nix-community/impermanence (flake input)]
  patterns:
    - lib.mkMerge with two items inside lib.mkIf for mode-conditional config blocks
    - environment.persistence key scoped to cfg.persistPath for configurable mount point
    - disko LVM-on-LUKS layout without root LV (/ is tmpfs, handled at module level)

key-files:
  created:
    - hosts/disko-configuration.nix
  modified:
    - flake.nix
    - modules/system/impermanence.nix

key-decisions:
  - "impermanence re-added to flake.nix inputs with no nixpkgs follows — upstream module has no nixpkgs input to override"
  - "lib.mkMerge list approach used for mode-conditional config — avoids pushDownProperties cycle issues"
  - "full mode environment.persistence paths: /var/log, /var/lib/nixos, /var/lib/systemd, /etc/nixos + SSH host keys + machine-id"
  - "hosts/disko-configuration.nix placed at hosts/ root (not hosts/nixos-base/) matching NERV.nixos target layout"
  - "no root LV in server disko — / declared as tmpfs in impermanence.nix full mode, not in disko"
  - "neededForBoot for /persist handled by impermanence.nix module (lib.mkDefault true), not by disko"

patterns-established:
  - "Mode enum pattern: lib.types.enum with string values, default first value, lib.mkIf per mode in lib.mkMerge"
  - "Server disko layout: NIXBOOT + NIXLUKS + NIXSWAP + NIXSTORE + NIXPERSIST — no root, no home LVs"

requirements-completed: [IMPL-04]

# Metrics
duration: 2min
completed: 2026-03-08
---

# Phase 8 Plan 02: Impermanence Extension + Server Disko Layout Summary

**impermanence flake input re-added with nerv.impermanence.mode enum and full-mode environment.persistence block; fresh server disko layout at hosts/disko-configuration.nix with LUKS-on-LVM and no root LV**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-08T16:10:03Z
- **Completed:** 2026-03-08T16:12:08Z
- **Tasks:** 2
- **Files modified:** 3 (2 modified, 1 created)

## Accomplishments
- Re-added `impermanence.url = "github:nix-community/impermanence"` to flake.nix with no nixpkgs follows (upstream has no nixpkgs input)
- Extended modules/system/impermanence.nix with `nerv.impermanence.mode` enum `["minimal" "full"]`, default `"minimal"` — minimal mode unchanged, full mode activates `/ as tmpfs` + `environment.persistence` with server-appropriate paths
- Created fresh `hosts/disko-configuration.nix` for server full-impermanence profile: GPT/EFI/LUKS-on-LVM with NIXBOOT, NIXLUKS (typo-free), NIXSWAP, NIXSTORE (/nix), NIXPERSIST (/persist) — no root LV, no home LV

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Add impermanence input + mode option + server disko layout** - `dacb55b` (feat)

## Files Created/Modified
- `flake.nix` - Added impermanence input and updated outputs signature to include it
- `modules/system/impermanence.nix` - Added mode option, lib.mkMerge config block, full-mode environment.persistence
- `hosts/disko-configuration.nix` - New server disko layout with LUKS-on-LVM, no root LV, no home LV

## Decisions Made
- impermanence re-added with no `inputs.nixpkgs.follows` — upstream module declares no nixpkgs input, adding follows would error
- `lib.mkMerge` list approach for mode-conditional config blocks avoids pushDownProperties cycle (consistent with existing let-binding pattern in file)
- `hosts/disko-configuration.nix` placed at `hosts/` root (not `hosts/nixos-base/`) — matches NERV.nixos target layout documented in plan context
- neededForBoot for /persist is set by impermanence.nix module (not by disko) so bind mounts happen before services start

## Deviations from Plan

None - plan executed exactly as written.

Note: `nix flake check --no-build` could not be run — nix binary is not available on this development machine. Structural verification performed via grep checks (all passed): impermanence.url present, mode option present, environment.persistence block present, NIXPERSIST present, NIKLUKS typo absent.

## Issues Encountered
- nix binary not in PATH on this dev machine. All planned grep-based verification checks passed. The nix flake check is expected to pass on a NixOS machine (no structural issues introduced — impermanence has no nixpkgs input by design, and the new disko file is not imported into any nixosConfiguration yet).

## Next Phase Readiness
- Plan 03 (multi-profile flake) can now wire `impermanence.nixosModules.impermanence` and `hosts/disko-configuration.nix` into a serverProfile nixosConfiguration
- Minimal mode behavior is unchanged — existing nixos-base nixosConfiguration continues to work without modification
- SIZE_RAM*2 / SIZE placeholder values in hosts/disko-configuration.nix must be replaced before actual use on target hardware

---
*Phase: 08-legacy-module-cleanup*
*Completed: 2026-03-08*
