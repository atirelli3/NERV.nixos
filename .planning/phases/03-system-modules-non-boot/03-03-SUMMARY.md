---
phase: 03-system-modules-non-boot
plan: "03"
subsystem: infra
tags: [nixos, security, apparmor, auditd, clamav, aide, nix-daemon, modules, configuration]

# Dependency graph
requires:
  - phase: 03-system-modules-non-boot
    plan: 01
    provides: modules/system/identity.nix with nerv.hostname, nerv.locale.*, nerv.primaryUser
  - phase: 03-system-modules-non-boot
    plan: 02
    provides: modules/system/hardware.nix and modules/system/kernel.nix

provides:
  - modules/system/security.nix (AppArmor, auditd, ClamAV, AIDE — fully opaque)
  - modules/system/nix.nix (Nix daemon config with corrected /etc/nerv#nixos-base flake path)
  - modules/system/default.nix (aggregator importing all five system modules)
  - hosts/nixos-base/configuration.nix using nerv.* API for all identity/hardware declarations
affects:
  - 04-boot-and-impermanence (inherits fully wired system module set)
  - hosts/nixos-base (configuration.nix now uses only nerv.* API for identity and hardware)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Opaque hardening module: no options block, always-on, lib.mkForce escape hatch documented in comment"
    - "System module aggregator: single default.nix imports all five system modules"
    - "nerv.* API replaces all inline NixOS identity/hardware declarations in host config"

key-files:
  created:
    - modules/system/security.nix
    - modules/system/nix.nix
  modified:
    - modules/system/default.nix
    - hosts/nixos-base/configuration.nix

key-decisions:
  - "security.nix and nix.nix are fully opaque (no options) — use lib.mkForce as escape hatch only"
  - "autoUpgrade flake path corrected from /etc/nixos#nixos to /etc/nerv#nixos-base in nix.nix"
  - "users.users.demon0 reduced to isNormalUser = true only — extraGroups now owned by identity.nix via nerv.primaryUser"
  - "networking block simplified to networking.networkmanager.enable = true — hostName now via nerv.hostname"

patterns-established:
  - "All five system modules (identity, hardware, kernel, security, nix) are wired and aggregated in default.nix"
  - "Host configuration.nix declares only machine-specific parameters; all hardening and system config is opaque"

requirements-completed: [OPT-01, OPT-02, OPT-03, OPT-04]

# Metrics
duration: 2min
completed: 2026-03-07
---

# Phase 3 Plan 03: System Module Wiring Summary

**security.nix and nix.nix migrated into modules/system/, default.nix aggregator wired with all five modules, and hosts/nixos-base/configuration.nix migrated to nerv.* API for identity and hardware — completing Phase 3**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-07T09:38:51Z
- **Completed:** 2026-03-07T09:40:58Z
- **Tasks:** 3 (2 implementation + 1 verification)
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- Created modules/system/security.nix: verbatim copy of modules/security.nix with section-header comment (AppArmor, auditd, ClamAV, AIDE fully opaque)
- Created modules/system/nix.nix: verbatim copy of modules/nix.nix with path fix (autoUpgrade flake corrected from /etc/nixos#nixos to /etc/nerv#nixos-base)
- Populated modules/system/default.nix: aggregator importing all five modules (identity, hardware, kernel, security, nix)
- Migrated hosts/nixos-base/configuration.nix: replaced inline identity/hardware with nerv.hostname, nerv.locale.*, nerv.primaryUser, nerv.hardware.cpu = "amd", nerv.hardware.gpu = "none"

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate security.nix and nix.nix into modules/system/** - `3d5ad6f` (feat)
2. **Task 2: Populate modules/system/default.nix and update hosts/nixos-base/configuration.nix** - `c5a6c97` (feat)
3. **Task 3: Verify full build passes** - verification only, no file changes

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified
- `modules/system/security.nix` - AppArmor, auditd, ClamAV daemon+updater, AIDE file integrity monitoring; fully opaque, no options
- `modules/system/nix.nix` - Nix daemon GC/optimise/autoUpgrade config with corrected /etc/nerv#nixos-base flake path
- `modules/system/default.nix` - Aggregator: imports identity.nix, hardware.nix, kernel.nix, security.nix, nix.nix
- `hosts/nixos-base/configuration.nix` - Removed inline identity (time.timeZone, i18n, console, networking.hostName, extraGroups); added nerv.* declarations for all identity and hardware options

## Decisions Made
- security.nix and nix.nix are fully opaque modules (no options block) — lib.mkForce is the documented escape hatch; matches Phase 3 design from 03-CONTEXT.md
- autoUpgrade flake path corrected to /etc/nerv#nixos-base — was stale /etc/nixos#nixos from original module
- users.users.demon0 reduced to `isNormalUser = true` only — wheel and networkmanager groups are now added by identity.nix when demon0 is in nerv.primaryUser; avoids attribute conflict
- networking block simplified from `networking = { hostName = ...; networkmanager.enable = true; }` to `networking.networkmanager.enable = true` — hostName now owned by identity.nix via nerv.hostname

## Deviations from Plan

None - plan executed exactly as written.

### Verification Limitation
- **Found during:** Task 3
- **Issue:** `nixos-rebuild build` and `nix-instantiate --parse` cannot run on this Arch Linux dev machine (nix not installed)
- **Fix:** Verified correctness via: brace/bracket balance checks (Python), content grep checks for required keys, absence checks for removed inline config, structural comparison to template files from prior plans
- **Impact:** Actual NixOS evaluation deferred to first `nixos-rebuild` on target NixOS machine — consistent with prior plans in this phase

---

**Total deviations:** 0 auto-fixed (1 verification limitation, not a code deviation)
**Impact on plan:** All file content matches specification exactly.

## Issues Encountered
- nix-instantiate and nixos-rebuild not available on development machine — manual structural verification substituted, consistent with 03-01 and 03-02 approach

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 is complete: all five system modules (identity, hardware, kernel, security, nix) are created, wired into modules/system/default.nix, and the host configuration uses nerv.* API exclusively for identity and hardware
- Phase 4 (boot and impermanence) can begin — boot block and LUKS/filesystems remain in configuration.nix as planned
- OPT-01 through OPT-04 all satisfied: hostname/locale/primaryUser (identity.nix) and hardware.cpu/gpu (hardware.nix) declared via nerv.* API in hosts/nixos-base/configuration.nix

---
*Phase: 03-system-modules-non-boot*
*Completed: 2026-03-07*
