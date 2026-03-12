---
phase: 02-services-reorganization
plan: 02
subsystem: infra
tags: [nixos, pipewire, bluetooth, printing, avahi, cups, wireplumber]

# Dependency graph
requires:
  - phase: 02-services-reorganization
    provides: services/default.nix scaffold and openssh options module pattern
provides:
  - modules/services/pipewire.nix — nerv.audio.enable option wrapping PipeWire stack
  - modules/services/bluetooth.nix — nerv.bluetooth.enable option wrapping Bluetooth stack
  - modules/services/printing.nix — nerv.printing.enable option wrapping CUPS + avahi
affects:
  - 02-03 (services/default.nix wiring — imports these three modules)
  - 02-04 (host configuration — enables nerv.audio, nerv.bluetooth, nerv.printing)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "enable-only options module: lib.mkEnableOption + lib.mkIf cfg.enable wrapping flat config"
    - "avahi ownership: each module declares its own avahi.enable = true; NixOS merges bool with logical OR"
    - "wireplumber codec config placed inside mkIf (no effect when PipeWire absent)"

key-files:
  created:
    - modules/services/pipewire.nix
    - modules/services/bluetooth.nix
    - modules/services/printing.nix
  modified: []

key-decisions:
  - "avahi.enable removed from pipewire.nix; ownership split to printing.nix and bluetooth.nix independently"
  - "printing.nix owns avahi.enable = true directly so printing works without nerv.audio enabled"
  - "bluetooth.nix owns avahi.enable = true independently for BT service mDNS advertisement"
  - "wireplumber extraConfig (10-bluez, 11-bluetooth-policy) lives inside mkIf cfg.enable block"
  - "Original flat modules/pipewire.nix, modules/bluetooth.nix, modules/printing.nix left untouched"

patterns-established:
  - "Enable-only module pattern: single nerv.*.enable option, entire body inside mkIf cfg.enable"
  - "Avahi dual-ownership: safe to declare avahi.enable = true in multiple modules (NixOS OR-merge)"
  - "Comment clarity: replace reliance-on-other-module comments with direct ownership comments"

requirements-completed: [OPT-08]

# Metrics
duration: 2min
completed: 2026-03-06
---

# Phase 2 Plan 02: Service Modules (PipeWire, Bluetooth, Printing) Summary

**Three enable-only NixOS options modules wrapping PipeWire, Bluetooth, and CUPS stacks with correct avahi ownership split across printing.nix and bluetooth.nix**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-06T22:19:36Z
- **Completed:** 2026-03-06T22:20:57Z
- **Tasks:** 3
- **Files modified:** 3 created

## Accomplishments

- `modules/services/pipewire.nix` wraps full PipeWire stack (alsa, pulse, raopOpenFirewall, low-latency config, pwvucontrol/helvum) behind `nerv.audio.enable`; avahi.enable removed
- `modules/services/bluetooth.nix` wraps Bluetooth stack (hardware.bluetooth, blueman, wireplumber codecs, obex, mpris-proxy) behind `nerv.bluetooth.enable`; adds avahi.enable ownership
- `modules/services/printing.nix` wraps CUPS stack behind `nerv.printing.enable`; directly owns both `avahi.enable = true` and `avahi.nssmdns4 = true` — independent of nerv.audio

## Task Commits

Each task was committed atomically:

1. **Task 1: Create modules/services/pipewire.nix** - `9fdbe3d` (feat)
2. **Task 2: Create modules/services/bluetooth.nix** - `a8764bc` (feat)
3. **Task 3: Create modules/services/printing.nix** - `f7313a5` (feat)

**Plan metadata:** _(see final commit hash below)_

## Files Created/Modified

- `modules/services/pipewire.nix` - PipeWire audio stack options module with nerv.audio.enable; avahi removed
- `modules/services/bluetooth.nix` - Bluetooth options module with nerv.bluetooth.enable; owns avahi.enable
- `modules/services/printing.nix` - CUPS printing options module with nerv.printing.enable; owns avahi.enable + nssmdns4

## Decisions Made

- Avahi ownership split: `printing.nix` and `bluetooth.nix` each declare `avahi.enable = true` independently. NixOS merges duplicate bool assignments with logical OR, so this is safe. This ensures CUPS network discovery works when `nerv.audio` is disabled.
- wireplumber codec config (`10-bluez`, `11-bluetooth-policy`) is inside the `mkIf cfg.enable` block — this matches the locked plan decision for clean conditional structure.
- Commented-out `hardware.printers` block preserved in `printing.nix` as user documentation.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three service modules ready to be imported into `modules/services/default.nix` (Plan 02-03)
- Each module independently toggleable via `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable`
- Original flat modules remain untouched until Phase 2 wiring is complete and verified

---
*Phase: 02-services-reorganization*
*Completed: 2026-03-06*

## Self-Check: PASSED

- modules/services/pipewire.nix: FOUND
- modules/services/bluetooth.nix: FOUND
- modules/services/printing.nix: FOUND
- 02-02-SUMMARY.md: FOUND
- Commit 9fdbe3d (Task 1): FOUND
- Commit a8764bc (Task 2): FOUND
- Commit f7313a5 (Task 3): FOUND
