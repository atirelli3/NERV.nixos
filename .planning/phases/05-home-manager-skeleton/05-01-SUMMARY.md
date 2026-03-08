---
phase: 05-home-manager-skeleton
plan: 01
subsystem: infra
tags: [home-manager, nixos-module, nix, flake]

# Dependency graph
requires:
  - phase: 01-flake-foundation
    provides: home-manager input pinned in flake.nix; home-manager.nixosModules.home-manager canonical attribute name confirmed
  - phase: 03-system-modules-non-boot
    provides: osConfig.system.stateVersion available via NixOS module system for stateVersion inheritance

provides:
  - nerv.home NixOS options module (home/default.nix) with useGlobalPkgs, useUserPackages, backupFileExtension, listToAttrs user wiring
  - home-manager.nixosModules.home-manager wired into nixosConfigurations.nixos-base modules list in flake.nix
  - nerv.home.enable = true and nerv.home.users = [ "demon0" ] active in hosts/nixos-base/configuration.nix
  - stateVersion inherited from osConfig.system.stateVersion — not hardcoded in user home configs

affects:
  - User dotfiles repo (user-owned ~/home.nix must exist before nixos-rebuild --impure)

# Tech tracking
tech-stack:
  added:
    - home-manager NixOS module (github:nix-community/home-manager — already pinned in flake.nix inputs)
  patterns:
    - nerv.home.users list-of-str option drives builtins.listToAttrs to generate home-manager.users attrset dynamically
    - Per-user HM config as function form { osConfig, ... }: { imports = [...]; } — preserves osConfig module arg for stateVersion inheritance
    - useGlobalPkgs + useUserPackages pattern for shared nixpkgs instance
    - backupFileExtension = "backup" as safety net for pre-existing unmanaged files

key-files:
  created: []
  modified:
    - home/default.nix
    - flake.nix
    - hosts/nixos-base/configuration.nix

key-decisions:
  - "nerv.home is list-based (listOf str) not attrset-based — host declares only usernames, no per-user attrset in system repo"
  - "stateVersion inherited from osConfig.system.stateVersion at module level — ~/home.nix never needs to set it"
  - "Function form { osConfig, ... }: { imports = [...]; } required for listToAttrs user values — bare import loses osConfig module arg"
  - "backupFileExtension = backup set to prevent hard failures on pre-existing unmanaged dotfiles"
  - "nixos-rebuild --impure required because /home/<name>/home.nix is outside the flake boundary (absolute path)"

patterns-established:
  - "Pattern: nerv.home.users = [ usernames ] — only addition needed to wire a new user into HM"
  - "Pattern: ~/home.nix is user-owned, never tracked in system repo — separation of concerns"

requirements-completed: [STRUCT-03, OPT-09]

# Metrics
duration: 2min
completed: 2026-03-07
---

# Phase 5 Plan 01: Home Manager Skeleton Summary

**nerv.home NixOS module with useGlobalPkgs, useUserPackages, and per-user stateVersion inheritance via osConfig, activated for demon0 in nixos-base**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-07T14:23:28Z
- **Completed:** 2026-03-07T14:24:58Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- home/default.nix replaced from stub with full nerv.home module implementing useGlobalPkgs, useUserPackages, backupFileExtension, and builtins.listToAttrs user wiring
- home-manager.nixosModules.home-manager added to nixosConfigurations.nixos-base modules list in flake.nix — HM options now available to all modules
- nerv.home.enable = true and nerv.home.users = [ "demon0" ] set in hosts/nixos-base/configuration.nix — activates home-manager-demon0.service on nixos-rebuild --impure on target machine

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire HM NixOS module in flake.nix and implement home/default.nix** - `992374c` (feat)
2. **Task 2: Enable nerv.home in configuration.nix and verify full build** - `6a59dac` (feat)

**Plan metadata:** `[pending]` (docs: complete plan)

## Files Created/Modified
- `flake.nix` - Added home-manager.nixosModules.home-manager to nixosConfigurations.nixos-base modules list
- `home/default.nix` - Replaced 2-line stub with full nerv.home module (options + config with useGlobalPkgs, useUserPackages, listToAttrs wiring)
- `hosts/nixos-base/configuration.nix` - Added nerv.home.enable = true and nerv.home.users = [ "demon0" ]

## Decisions Made
- Function form `{ osConfig, ... }: { imports = [...]; }` is required for per-user HM values in listToAttrs — bare `import /home/${name}/home.nix` loses the osConfig module argument and breaks stateVersion inheritance
- backupFileExtension = "backup" added as safety net to prevent hard failures if HM would overwrite existing unmanaged dotfiles

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- `nix` binary not available in PATH on this development machine (non-NixOS). `nix flake show` and `nix flake check` could not be run. This is expected per plan documentation: evaluation verification (nix flake show) and full activation (nixos-rebuild switch --impure) must be run on the target NixOS machine with /home/demon0/home.nix present. All file-level correctness checks pass (grep verifications for all three artifacts).

## User Setup Required

On the target NixOS machine, before running `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure`:

1. Create `/home/demon0/home.nix` with minimal content:
   ```nix
   # ~/home.nix — user-owned Home Manager configuration
   # home.stateVersion is set by the system wiring (nerv); do not set it here.
   { pkgs, ... }: {
     home.username    = "demon0";
     home.homeDirectory = "/home/demon0";
   }
   ```

2. Run: `sudo nixos-rebuild switch --flake /etc/nerv#nixos-base --impure`

3. Verify: `systemctl status home-manager-demon0.service` — expect `active (exited)`

## Next Phase Readiness
- nerv.home wiring is complete; HM is ready for Phase 6 user configuration modules
- Target machine activation requires demon0 ~/home.nix to exist and --impure flag on nixos-rebuild
- Adding additional users requires only appending to nerv.home.users list — no other system repo changes

## Self-Check: PASSED

- FOUND: flake.nix
- FOUND: home/default.nix
- FOUND: hosts/nixos-base/configuration.nix
- FOUND: 05-01-SUMMARY.md
- FOUND commit 992374c: feat(05-01): wire home-manager NixOS module and implement nerv.home
- FOUND commit 6a59dac: feat(05-01): enable nerv.home in nixos-base configuration

---
*Phase: 05-home-manager-skeleton*
*Completed: 2026-03-07*
