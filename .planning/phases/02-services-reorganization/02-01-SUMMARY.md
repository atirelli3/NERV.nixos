---
phase: 02-services-reorganization
plan: 01
subsystem: infra
tags: [nixos, openssh, endlessh, fail2ban, nix-modules, options-pattern]

# Dependency graph
requires:
  - phase: 01-flake-foundation
    provides: root flake.nix with nixosModules wiring that will import services/default.nix

provides:
  - modules/services/openssh.nix: NixOS options module wrapping OpenSSH + endlessh tarpit + fail2ban behind nerv.openssh.* API

affects:
  - 02-02 through 02-07: establishes multi-option module skeleton pattern used by all remaining Phase 2 service modules
  - 03-wiring: services/default.nix will import this file; modules/openssh.nix removed in that plan

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "multi-option NixOS module: cfg = config.nerv.<service>; options.nerv.<service> = { enable = mkEnableOption; ... }; config = lib.mkIf cfg.enable { ... }"
    - "AllowUsers empty-list guard via lib.optionalAttrs (cfg.allowUsers != []) prevents lockout"
    - "int-to-string conversion: toString cfg.port for fail2ban jail port string field"
    - "tarpitPort assertion pattern: assertion = cfg.tarpitPort != cfg.port"

key-files:
  created:
    - modules/services/openssh.nix
  modified: []

key-decisions:
  - "AllowUsers omitted entirely when allowUsers is empty (lib.optionalAttrs guard) — empty AllowUsers in sshd locks everyone out"
  - "fail2ban jail port is toString cfg.port, not a hardcoded string — ensures port changes propagate automatically"
  - "Original modules/openssh.nix left untouched — removed only in Plan 03 when wiring happens to avoid breaking existing config"
  - "endlessh and fail2ban are always-on when nerv.openssh.enable = true — no separate enable toggles for security-critical subsystems"

patterns-established:
  - "Pattern 1 — multi-option skeleton: options block + let cfg = ...; + config = lib.mkIf cfg.enable { assertions = [...]; services = {...}; }"
  - "Pattern 2 — conditional attribute merge: settings = { ... } // lib.optionalAttrs condition { extraAttr = value; }"
  - "Pattern 3 — type coercion comment: # types.port is int; <downstream> setting expects a string"

requirements-completed: [OPT-05, OPT-06, OPT-07]

# Metrics
duration: 3min
completed: 2026-03-06
---

# Phase 2 Plan 01: OpenSSH Options Module Summary

**NixOS options module for openssh + endlessh tarpit + fail2ban behind nerv.openssh.* API, with AllowUsers lockout guard, port stringification, and tarpitPort collision assertion**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-06T22:19:29Z
- **Completed:** 2026-03-06T22:22:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `modules/services/openssh.nix` with full typed options block (enable, port, tarpitPort, allowUsers, passwordAuth, kbdInteractiveAuth)
- Wrapped openssh + endlessh + fail2ban under `lib.mkIf cfg.enable` — services inactive unless opt-in
- Implemented AllowUsers guard: `lib.optionalAttrs (cfg.allowUsers != [])` prevents sshd lockout from empty AllowUsers
- Dynamic fail2ban port: `toString cfg.port` replaces hardcoded `"2222"` string
- Added assertion `cfg.tarpitPort != cfg.port` with descriptive error message

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/services/openssh.nix** - `62ac6fc` (feat)

## Files Created/Modified

- `modules/services/openssh.nix` - NixOS options module; nerv.openssh.* API wrapping openssh daemon, endlessh tarpit, and fail2ban rate-limiter

## Decisions Made

- AllowUsers omitted entirely when list is empty (lib.optionalAttrs guard) — empty AllowUsers in sshd means "allow nobody", which would lock out all users
- `toString cfg.port` used for fail2ban jail port — `lib.types.port` is an integer but fail2ban expects a string; explicit coercion with inline comment documents the type mismatch
- Original `modules/openssh.nix` left untouched per plan — will be removed in Plan 03 when wiring is done to avoid breaking the existing config in the interim
- endlessh and fail2ban are unconditionally enabled when `nerv.openssh.enable = true` — no separate toggles since these are mandatory security components of the SSH stack

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `modules/services/openssh.nix` is complete and ready for import in Plan 03 (wiring phase)
- Multi-option module pattern established: subsequent Plan 02 modules (bluetooth, pipewire, printing, etc.) follow the same skeleton
- No blockers

---
*Phase: 02-services-reorganization*
*Completed: 2026-03-06*
