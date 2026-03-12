---
phase: 02-services-reorganization
plan: "03"
subsystem: infra
tags: [nixos, nix, zsh, services, modules, options-api]

# Dependency graph
requires:
  - phase: 02-01
    provides: modules/services/openssh.nix with nerv.openssh.* options API
  - phase: 02-02
    provides: modules/services/pipewire.nix, bluetooth.nix, printing.nix with nerv.* options API

provides:
  - modules/services/zsh.nix — nerv.zsh.enable option wrapping full zsh configuration
  - modules/services/default.nix — aggregator importing all five service modules
  - hosts/nixos-base/configuration.nix — host config declaring nerv.* service options

affects:
  - phase-03-system-reorganization
  - phase-05-home-manager
  - any future phase importing modules/services/

# Tech tracking
tech-stack:
  added: []
  patterns:
    - nerv.* options API pattern fully established across all five service modules
    - services/default.nix as single aggregation import point for service layer
    - host configuration declares only nerv.* options (no direct NixOS config in host file)

key-files:
  created:
    - modules/services/zsh.nix
  modified:
    - modules/services/default.nix
    - hosts/nixos-base/configuration.nix

key-decisions:
  - "nix aliases hardcoded to /etc/nerv#nixos-base in zsh.nix (old values /etc/nixos#nixos removed)"
  - "starship and fonts blocks not migrated to zsh.nix — they belong to a separate concern (UI/cosmetics)"
  - "nerv.audio.enable, nerv.bluetooth.enable, nerv.printing.enable all set to false in host config — enabled only on target NixOS machine with real hardware"
  - "nix flake check deferred to NixOS target machine — nix CLI unavailable on Arch Linux dev machine"

patterns-established:
  - "Pattern: interactiveShellInit load order comment preserved verbatim — autosuggestions before syntax-highlighting before history-substring-search"
  - "Pattern: host configuration.nix uses only nerv.* API; no direct NixOS service config at host level"
  - "Pattern: services/default.nix is the single imports aggregator — callers import only this file"

requirements-completed:
  - OPT-08

# Metrics
duration: 2min
completed: 2026-03-06
---

# Phase 2 Plan 3: Zsh module, services aggregator, and host config wiring Summary

**Five service modules wired via nerv.* options API: zsh.nix created, services/default.nix populated, host configuration.nix declares all nerv service options**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-06T22:26:07Z
- **Completed:** 2026-03-06T22:28:00Z
- **Tasks:** 3 (2 executed + 1 deferred verification)
- **Files modified:** 3

## Accomplishments

- Created `modules/services/zsh.nix` wrapping the full zsh configuration behind `nerv.zsh.enable`, with nix aliases updated to `/etc/nerv#nixos-base`, starship and fonts blocks removed, and interactiveShellInit load order preserved
- Populated `modules/services/default.nix` with all five service module imports (openssh, pipewire, bluetooth, printing, zsh) — no secureboot
- Updated `hosts/nixos-base/configuration.nix` to declare nerv service options: openssh enabled with allowUsers=["demon0"], audio/bluetooth/printing disabled, zsh enabled

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/services/zsh.nix** - `550e13c` (feat)
2. **Task 2: Wire services/default.nix and update host config** - `bcdb381` (feat)
3. **Task 3: nix flake check** - deferred (nix CLI unavailable on dev machine)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `modules/services/zsh.nix` — nerv.zsh.enable option module; zsh config migrated from modules/zsh.nix with aliases updated and starship/fonts blocks removed
- `modules/services/default.nix` — replaces stub with five service module imports
- `hosts/nixos-base/configuration.nix` — added nerv.openssh, nerv.audio, nerv.bluetooth, nerv.printing, nerv.zsh option declarations

## Decisions Made

- Nix aliases updated to `/etc/nerv#nixos-base` in zsh.nix (locked decision from plan — hardcoded path)
- `starship` and `fonts` blocks not migrated — they belong to a separate cosmetics concern, left in `modules/zsh.nix`
- `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable` set to `false` in host config — only enabled on physical NixOS machine with matching hardware
- `nix flake check` deferred: nix CLI is not installed on this Arch Linux dev machine

## Deviations from Plan

None — plan executed exactly as written. Task 3 (nix flake check) is a documented deferral per the plan's own instructions when nix is unavailable.

### Deferred Verification

**nix flake check — run on NixOS target machine before Phase 3 begins:**

```bash
cd /etc/nerv
nix flake check

# Full build verification
nixos-rebuild build --flake .#nixos-base

# If evaluation errors occur, check:
# - Type mismatch in fail2ban port: verify `toString cfg.port` in openssh.nix
# - AllowUsers evaluation error: verify `optionalAttrs (cfg.allowUsers != [])` guard in openssh.nix
# - Missing import: verify modules/services/default.nix lists all five modules
# - Evaluation conflict: check for duplicate option definitions
```

## Issues Encountered

None — all file checks passed on the first attempt.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 2 (services reorganization) is fully authored and wired
- `modules/services/default.nix` is the single import point for the entire service layer
- All nerv.* service options are declared in `hosts/nixos-base/configuration.nix`
- **Pre-condition before Phase 3:** Run `nix flake check` on NixOS target machine to confirm no evaluation errors
- `modules/zsh.nix` (the original flat module) is still present but no longer the canonical location — it can be removed in a cleanup pass when Phase 2 is formally closed on the NixOS machine

---
*Phase: 02-services-reorganization*
*Completed: 2026-03-06*
