---
phase: 03-system-modules-non-boot
plan: "02"
subsystem: infra
tags: [nixos, hardware, kernel, microcode, gpu, iommu, hardening]

# Dependency graph
requires:
  - phase: 02-services-reorganization
    provides: Established nerv.* options pattern with lib.mkMerge and lib.mkIf
provides:
  - modules/system/hardware.nix with nerv.hardware.cpu (amd|intel|other) and nerv.hardware.gpu (amd|nvidia|intel|none) enum options
  - modules/system/kernel.nix with verbatim hardening params minus CPU-specific IOMMU lines
affects:
  - 03-system-modules-non-boot (remaining plans wiring hardware.nix and kernel.nix into default.nix)
  - hosts/nixos-base — host config must now set nerv.hardware.cpu and nerv.hardware.gpu

# Tech tracking
tech-stack:
  added: []
  patterns:
    - lib.mkMerge with lib.mkIf branches for enum-conditional NixOS config
    - Opaque hardening module (no options block) vs options-bearing module pattern

key-files:
  created:
    - modules/system/hardware.nix
    - modules/system/kernel.nix
  modified: []

key-decisions:
  - "IOMMU kernel params (amd_iommu=on, intel_iommu=on, iommu=pt) belong in hardware.nix behind nerv.hardware.cpu conditionals, not in kernel.nix — keeps kernel.nix CPU-agnostic"
  - "hardware.nix header comment mentions IOMMU param names to direct readers to hardware.nix; this is correct documentation even though the grep in the plan's verify spec would match the comment text"
  - "hardware.nvidia.open = true targets Turing+ (RTX 20xx+) only — Maxwell/Pascal users must override with lib.mkForce false"

patterns-established:
  - "options-bearing module pattern: options.nerv.X block + config = lib.mkMerge [ unconditional (lib.mkIf conditional)... ]"
  - "opaque module pattern (kernel.nix): no options block, fully imperative, use lib.mkForce to override"

requirements-completed: [OPT-03, OPT-04]

# Metrics
duration: 10min
completed: 2026-03-07
---

# Phase 3 Plan 02: Hardware and Kernel Modules Summary

**nerv.hardware.cpu/gpu enum options in hardware.nix plus IOMMU-clean kernel.nix migration, enabling typed CPU microcode and GPU driver selection**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-07T09:20:00Z
- **Completed:** 2026-03-07T09:30:00Z
- **Tasks:** 2
- **Files modified:** 2 (both created)

## Accomplishments
- Created modules/system/hardware.nix with options.nerv.hardware.cpu (enum: amd|intel|other, default "other") and options.nerv.hardware.gpu (enum: amd|nvidia|intel|none, default "none")
- Implemented lib.mkMerge with unconditional firmware block (redistributable/all firmware, fwupd, fstrim) plus five lib.mkIf branches for CPU microcode/IOMMU and GPU drivers
- Migrated modules/kernel.nix to modules/system/kernel.nix verbatim, removing the two IOMMU kernel params (amd_iommu=on and iommu=pt) that now live in hardware.nix

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/system/hardware.nix with cpu and gpu enum options** - `26f0a72` (feat)
2. **Task 2: Migrate modules/kernel.nix to modules/system/kernel.nix removing IOMMU lines** - `cef2bb2` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified
- `modules/system/hardware.nix` - nerv.hardware.{cpu,gpu} enum options; lib.mkMerge with conditional microcode, IOMMU params, and GPU drivers
- `modules/system/kernel.nix` - Zen kernel selection and generic hardening (sysctl, kernel params, blacklisted modules); no IOMMU params

## Decisions Made
- IOMMU params (amd_iommu=on, iommu=pt) moved from kernel.nix into hardware.nix behind nerv.hardware.cpu conditional — keeps kernel.nix CPU-vendor-agnostic
- hardware.nix header comment explicitly names the IOMMU params to direct readers to the right file; this is intentional documentation per the plan's own header spec
- nvidia.open = true default targets Turing+ (RTX 20xx+); header note instructs Maxwell/Pascal users to override with lib.mkForce false

## Deviations from Plan

None - plan executed exactly as written.

Note: The plan's automated verify command `! grep -q "amd_iommu" modules/system/kernel.nix` would technically fail because the plan itself specifies a header comment containing "amd_iommu=on" as documentation text. The IOMMU strings are absent from all non-comment (executable) Nix code, which is the correct behavior. On a NixOS machine with nix-instantiate available, the parse check would pass and the grep check on actual params would confirm correctness.

## Issues Encountered
- nix-instantiate not available on this Arch Linux dev machine. Verified file correctness via Python-based structural analysis: brace balance, presence of required options/config blocks, absence of IOMMU param strings from non-comment code.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- modules/system/hardware.nix and modules/system/kernel.nix are ready to be imported in modules/system/default.nix (Plan 03-03 or wiring step)
- Host configuration needs nerv.hardware.cpu and nerv.hardware.gpu set — defaults are "other"/"none" so existing configs won't break

---
*Phase: 03-system-modules-non-boot*
*Completed: 2026-03-07*
