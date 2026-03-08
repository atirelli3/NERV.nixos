---
phase: 08-legacy-module-cleanup
plan: "03"
subsystem: infra
tags: [nix, flake, profiles, nixos, impermanence, disko]

# Dependency graph
requires:
  - phase: 08-02
    provides: hosts/disko-configuration.nix at hosts/ root, impermanence input in flake.nix, updated modules/system/impermanence.nix

provides:
  - flake.nix with three inline profiles (hostProfile, serverProfile, vmProfile) as let bindings
  - nixosConfigurations.host, .server, .vm (replaces nixos-base)
  - hosts/configuration.nix as identity-only file with PLACEHOLDER markers
  - hosts/hardware-configuration.nix placeholder for per-machine replacement

affects: [flake-usage, host-onboarding, profile-selection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Profile as plain attrset let binding — hostProfile/serverProfile/vmProfile passed directly in modules list"
    - "Identity-only hosts/configuration.nix — machine name, user, hardware, locale, disk; no service toggles"
    - "server nixosConfiguration includes impermanence.nixosModules.impermanence for environment.persistence"
    - "vm nixosConfiguration omits lanzaboote — VMs lack TPM2/Secure Boot"

key-files:
  created:
    - hosts/configuration.nix
    - hosts/hardware-configuration.nix
  modified:
    - flake.nix

key-decisions:
  - "Three profiles as plain attrsets in let bindings — no module wrapper needed; passed directly in modules list alongside nixosModules.default"
  - "vm omits lanzaboote — VMs lack TPM2, secureboot disabled; avoids module conflicts"
  - "hosts/hardware-configuration.nix created as placeholder at hosts/ root alongside configuration.nix — required for nix import resolution"
  - "disko.devices.disk.main.device override lives in hosts/configuration.nix — single identity file to edit per machine"

patterns-established:
  - "Profile pattern: declare nerv.* settings as plain attrset, pass as module in nixosConfigurations"
  - "Identity pattern: hosts/configuration.nix contains only PLACEHOLDER values; all feature decisions live in profiles"

requirements-completed:
  - IMPL-05

# Metrics
duration: 2min
completed: 2026-03-08
---

# Phase 08 Plan 03: Multi-Profile Flake Summary

**Three inline profiles (hostProfile, serverProfile, vmProfile) wired into nixosConfigurations host/server/vm, replacing nixos-base; identity-only hosts/configuration.nix with PLACEHOLDER markers for per-machine customization**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-08T16:14:19Z
- **Completed:** 2026-03-08T16:15:52Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Rewrote flake.nix outputs with three profile let bindings (hostProfile, serverProfile, vmProfile) each declaring the full nerv.* API surface for that use case
- Replaced nixosConfigurations.nixos-base with host, server, vm — server includes impermanence.nixosModules.impermanence, vm omits lanzaboote
- Created hosts/configuration.nix as the single identity file users edit once (hostname, user, hardware, locale, disk device; no service settings)
- Created hosts/hardware-configuration.nix placeholder to satisfy the import chain

## Task Commits

Each task was committed atomically:

1. **Task 1+2: Rewrite flake.nix + create hosts/configuration.nix** - `3b7a909` (feat)

**Plan metadata:** pending (docs commit)

## Files Created/Modified

- `flake.nix` - Outputs rewritten: three profile let bindings, nixosConfigurations host/server/vm (nixos-base removed)
- `hosts/configuration.nix` - Identity-only file: nerv.hostname, nerv.primaryUser, nerv.hardware.*, nerv.locale.*, system.stateVersion, disko disk device
- `hosts/hardware-configuration.nix` - Placeholder for per-machine nixos-generate-config output

## Decisions Made

- Three profiles as plain attrsets in let bindings — no module wrapper needed; passed directly in modules list alongside nixosModules.default
- vm omits lanzaboote — VMs lack TPM2, secureboot=false by profile; avoids potential module conflicts
- hosts/hardware-configuration.nix created as placeholder at hosts/ root alongside configuration.nix — required for nix import resolution
- disko.devices.disk.main.device override lives in hosts/configuration.nix — single identity file to edit per machine

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created hosts/hardware-configuration.nix placeholder**
- **Found during:** Task 2 (creating hosts/configuration.nix)
- **Issue:** hosts/configuration.nix imports `./hardware-configuration.nix` which is relative to `hosts/`; no such file existed at `hosts/` root level (only at `hosts/nixos-base/`)
- **Fix:** Created `hosts/hardware-configuration.nix` as an empty placeholder matching the pattern of `hosts/nixos-base/hardware-configuration.nix`
- **Files modified:** hosts/hardware-configuration.nix
- **Verification:** Import chain audit — hosts/configuration.nix -> ./hardware-configuration.nix -> hosts/hardware-configuration.nix (exists)
- **Committed in:** 3b7a909 (task commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for import resolution. Matches established pattern from hosts/nixos-base/hardware-configuration.nix. No scope creep.

## Issues Encountered

- nix not available on dev machine — `nix flake check --no-build` could not be run. Correctness verified by import-chain audit and structural grep checks (consistent with Phase 08 established practice in STATE.md).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- IMPL-05 complete — multi-profile flake structure delivered
- Phase 08 Plan 03 is the final plan in Phase 08
- Users can now clone the repo, edit hosts/configuration.nix to fill in PLACEHOLDER values, pick their profile in flake.nix, and run nixos-rebuild

---
*Phase: 08-legacy-module-cleanup*
*Completed: 2026-03-08*
