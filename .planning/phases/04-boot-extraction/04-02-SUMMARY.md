---
phase: 04-boot-extraction
plan: "02"
subsystem: infra
tags: [nixos, impermanence, tmpfs, fileSystems, systemd-tmpfiles, secureboot]

# Dependency graph
requires:
  - phase: 03-system-modules-non-boot
    provides: identity.nix with nerv.primaryUser list-of-strings type used for default per-user mounts
provides:
  - modules/system/impermanence.nix — option-bearing NixOS module with nerv.impermanence.{enable,persistPath,extraDirs,users}
  - nerv.impermanence.enable = false default — no fileSystems entries added until wired
  - IMPL-02 sbctl safety assertion using lib.optional config.nerv.secureboot.enable
  - Default /tmp and /var/tmp tmpfs mounts + per-user Desktop/Downloads + custom cfg.users mounts
affects:
  - 04-03 (wiring plan): imports impermanence.nix into modules/system/default.nix
  - 04-04 (secureboot plan): impermanence.nix references config.nerv.secureboot.enable for IMPL-02

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lib.mkMerge top-level combiner for multiple fileSystems attrsets"
    - "lib.optional for conditional assertions (secureboot-gated sbctl check)"
    - "systemd.tmpfiles.rules d entries to pre-create tmpfs mount points"
    - "builtins.map + lib.mkMerge for generating fileSystems from list options"
    - "lib.mapAttrsToList + lib.concatLists for generating fileSystems from attrsOf attrsOf"

key-files:
  created:
    - modules/system/impermanence.nix
  modified: []

key-decisions:
  - "lib.optional config.nerv.secureboot.enable used for IMPL-02 assertion — assertion only fires when secureboot is also enabled, preventing evaluation errors before secureboot.nix is wired"
  - "systemd.tmpfiles.rules d entries added for all user-facing mount points — prevents boot failure when directory is absent on disk (Pitfall 5)"
  - "lib.mkMerge wraps top-level config block so multiple fileSystems attrsets merge cleanly without manual ++/union"
  - "builtins.map used instead of lib.genAttrs for extraDirs/per-user defaults — preserves generated attrset structure compatible with lib.mkMerge"

patterns-established:
  - "Pattern: per-user default mounts via builtins.map over config.nerv.primaryUser inside lib.mkMerge"
  - "Pattern: per-user custom mounts via lib.mapAttrsToList + lib.concatLists + lib.mapAttrsToList iterating cfg.users attrsOf attrsOf"

requirements-completed: [IMPL-01, IMPL-02, IMPL-03]

# Metrics
duration: 6min
completed: 2026-03-07
---

# Phase 4 Plan 02: Impermanence Module Summary

**Selective per-directory tmpfs impermanence module with sbctl safety assertion and per-user mount generation via nerv.impermanence.* options**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-07T10:51:54Z
- **Completed:** 2026-03-07T10:58:18Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created modules/system/impermanence.nix with all four nerv.impermanence.* options (enable, persistPath, extraDirs, users) with correct NixOS types and defaults
- IMPL-02 sbctl safety assertion implemented using lib.optional config.nerv.secureboot.enable — fails at evaluation time with a clear error message if any impermanence path conflicts with /var/lib/sbctl
- Default /tmp and /var/tmp tmpfs mounts at size=25% with mode=1777 nosuid nodev; per-user Desktop + Downloads defaults; cfg.users custom mounts — all via lib.mkMerge
- systemd.tmpfiles.rules d entries added for all user home subdirectory mount points to prevent boot failure on missing directories

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/system/impermanence.nix** - `245a8a6` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `modules/system/impermanence.nix` - New option-bearing NixOS module implementing selective per-directory tmpfs impermanence; not yet imported (wiring happens in Plan 03)

## Decisions Made

- Used `lib.optional config.nerv.secureboot.enable` for the IMPL-02 assertion rather than nesting inside a separate `lib.mkIf`. This keeps the assertion list flat and prevents the assertion from causing evaluation errors when secureboot.nix has not yet been wired (Plan 03). The plan specified `lib.optional` explicitly.
- Used `systemd.tmpfiles.rules` with `d` entries for pre-creating user home subdirectory mount points. This follows the research recommendation (Pitfall 5) and is the cleanest NixOS idiom — the tmpfiles service runs before user mounts are activated.
- `lib.mkMerge` wraps the entire inner config block, allowing separate attrsets for system defaults, extraDirs, per-user defaults, and per-user custom mounts to be cleanly merged without explicit attrset union operators.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- nix/nix-instantiate tooling not available in the dev environment (not a NixOS machine), so `nix-instantiate --parse` and `nixos-rebuild build` verification could not run. File syntax verified by inspection. The module is not yet imported into the flake, so build impact is zero until Plan 03 wiring.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- modules/system/impermanence.nix is complete and ready for Plan 03 (wiring) to import it into modules/system/default.nix
- nerv.impermanence.enable defaults to false — module can be imported without any active effect until host configuration sets enable = true
- IMPL-02 assertion references config.nerv.secureboot.enable — this will become live once secureboot.nix is wired in Plan 03/04; no evaluation errors until then because lib.optional only appends the assertion attrset when secureboot.enable evaluates to true

---
*Phase: 04-boot-extraction*
*Completed: 2026-03-07*
