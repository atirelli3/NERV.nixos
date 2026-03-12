---
phase: 03-system-modules-non-boot
plan: 01
subsystem: infra
tags: [nixos, nix, modules, identity, locale, users]

# Dependency graph
requires:
  - phase: 02-services-reorganization
    provides: established nerv.* options pattern (openssh.nix, zsh.nix as template)
provides:
  - options.nerv.hostname (required str, wired to networking.hostName)
  - options.nerv.locale.timeZone (default UTC)
  - options.nerv.locale.defaultLocale (default en_US.UTF-8)
  - options.nerv.locale.keyMap (default us)
  - options.nerv.primaryUser (list of str, auto wheel+networkmanager+zsh shell)
affects: [03-system-modules-non-boot, 04-boot-and-impermanence, host-configuration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lib.mkMerge for multi-fragment config blocks with always-on + conditional sections"
    - "lib.genAttrs + lib.optionalAttrs for cross-module user attribute merging"
    - "options.nerv.* without enclosing enable guard for always-active identity module"

key-files:
  created:
    - modules/system/identity.nix
  modified: []

key-decisions:
  - "nerv.hostname has no default — forces explicit declaration, prevents silent misconfiguration"
  - "console.font/packages hardcoded to ter-v18n/terminus_font with lib.mkForce escape hatch documented in comment"
  - "Cross-wiring to config.nerv.zsh.enable is safe because NixOS merges all modules before evaluation"

patterns-established:
  - "Identity module has no enable guard — machine always has a hostname and locale"
  - "lib.mkMerge with always-on fragment + lib.mkIf conditional fragment for optional user wiring"

requirements-completed: [OPT-01, OPT-02]

# Metrics
duration: 1min
completed: 2026-03-07
---

# Phase 3 Plan 01: Identity Module Summary

**nerv.hostname/locale/primaryUser options in a single NixOS module, wiring machine identity and primary users declaratively with sensible defaults**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-07T09:35:12Z
- **Completed:** 2026-03-07T09:36:01Z
- **Tasks:** 1 of 1
- **Files modified:** 1

## Accomplishments
- Created modules/system/identity.nix with all five option declarations (hostname, locale.timeZone, locale.defaultLocale, locale.keyMap, primaryUser)
- Config block wires all identity values to NixOS options via lib.mkMerge
- primaryUser users automatically receive wheel+networkmanager groups; gain pkgs.zsh shell when nerv.zsh.enable is true via lib.optionalAttrs cross-wiring

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/system/identity.nix with hostname and locale options** - `7df4b4c` (feat)

## Files Created/Modified
- `modules/system/identity.nix` - NixOS module declaring nerv.hostname, nerv.locale.*, nerv.primaryUser with full config wiring

## Decisions Made
- nerv.hostname declared without a default value — forces explicit host declaration, prevents silent empty-string hostname
- console.font and console.packages are hardcoded to ter-v18n/terminus_font with a comment explaining lib.mkForce escape hatch
- Cross-module reference to config.nerv.zsh.enable is safe because NixOS evaluates all modules together before applying config

## Deviations from Plan

### Verification Limitation
- **Found during:** Task 1 verification
- **Issue:** `nix-instantiate --parse` could not be run — nix is not installed on this development machine (not a NixOS host)
- **Fix:** Manual syntactic review against Nix language grammar and comparison to openssh.nix template confirmed file is correct; all braces, brackets, and `//` operators are balanced; all five options present; both config fragments present with correct lib.mkMerge/lib.mkIf structure
- **Impact:** Parse verification deferred to first `nixos-rebuild` on target NixOS machine

---

**Total deviations:** 0 auto-fixed (1 verification limitation, not a code deviation)
**Impact on plan:** Module content matches specification exactly. Verification will be confirmed on first NixOS build.

## Issues Encountered
- nix-instantiate not available on development machine — manual review substituted for automated parse check

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- modules/system/identity.nix ready to be imported in modules/system/default.nix (Plan 03-02 or 03-03)
- Host configuration.nix can replace direct networking.hostName/time.timeZone/etc. with nerv.hostname/locale.* declarations
- No blockers
