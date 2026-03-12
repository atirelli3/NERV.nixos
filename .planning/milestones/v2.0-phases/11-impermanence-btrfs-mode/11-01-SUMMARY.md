---
phase: 11-impermanence-btrfs-mode
plan: 01
subsystem: infra
tags: [nix, impermanence, btrfs, persistence, environment.persistence, neededForBoot]

# Dependency graph
requires:
  - phase: 10-initrd-btrfs-rollback-service
    provides: "@root-blank rollback service that resets BTRFS @ on each boot; /persist as @persist subvolume"
  - phase: 09-btrfs-disko-layout
    provides: "disko BTRFS layout with @persist subvolume mounted at /persist"
provides:
  - "nerv.impermanence.mode = btrfs activates environment.persistence bind-mounts from /persist"
  - "fileSystems./persist.neededForBoot = lib.mkDefault true in btrfs block"
  - "mode enum [btrfs, full] with no default — minimal mode removed"
affects:
  - phase: 12-profile-wiring
    note: "hostProfile and vmProfile must be updated from mode=minimal to mode=btrfs"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lib.mkMerge with three entries: common, full-mode, btrfs-mode — avoids pushDownProperties cycle"
    - "Static persistDirs let binding to avoid self-reference in warnings check"
    - "lib.mkDefault true on neededForBoot — overridable per host with lib.mkForce"

key-files:
  created: []
  modified:
    - modules/system/impermanence.nix

key-decisions:
  - "mode enum is [btrfs, full] with NO default — forces explicit declaration per host (consistent with nerv.hostname, nerv.disko.layout)"
  - "/var/lib persisted as single broad directory in btrfs mode — covers all service state (nixos, systemd, sbctl, BT, NM, cups) in one entry"
  - "/var/log intentionally absent from btrfs persistence — @log BTRFS subvolume handles logs; double-mount would conflict at stage-2 activation"
  - "sbctl warning uses static persistDirs list — avoids self-reference cycle from inspecting environment.persistence inside the same mkIf block"
  - "/tmp and /var/tmp tmpfs mounts removed from common block — btrfs mode does not need them (BTRFS @ is reset by rollback, not tmpfs)"
  - "IMPL-02 sbctl assertion in common block retained — still guards extraDirs/users from accidentally including /var/lib/sbctl as tmpfs"

patterns-established:
  - "Static list guard for warnings that check self-referential attrsets: define persistDirs = [ ... ] locally, check that list"

requirements-completed: [PERSIST-01, PERSIST-02]

# Metrics
duration: 3min
completed: 2026-03-10
---

# Phase 11 Plan 01: Impermanence BTRFS Mode Summary

**BTRFS impermanence mode added to impermanence.nix: mode enum [btrfs, full] with no default, /var/lib + /etc/nixos + five SSH/machine-id files persisted from @persist, /var/log excluded, neededForBoot wired, minimal mode removed**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-10T09:00:26Z
- **Completed:** 2026-03-10T09:03:30Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Rewrote mode option: enum changed from ["minimal", "full"] to ["btrfs", "full"] with no default, consistent with nerv.hostname and nerv.disko.layout pattern
- Added third lib.mkMerge entry (btrfs block) containing: `fileSystems."/persist".neededForBoot = lib.mkDefault true`, `environment.persistence."/persist"` with /var/lib, /etc/nixos, and five SSH/machine-id files, plus sbctl warning guard
- Removed /tmp and /var/tmp tmpfs fileSystems from common block (btrfs mode does not use tmpfs root; those were minimal-mode artifacts)
- Updated module header to reflect btrfs and full modes (minimal removed from all documentation)

## Task Commits

Each task was committed atomically:

1. **Task 1: Drop minimal mode — rewrite enum, remove /tmp /var/tmp fileSystems, update header** - `89c39ec` (feat)
2. **Task 2: Add btrfs lib.mkIf block with neededForBoot, environment.persistence, and sbctl warning** - `cd7136e` (feat)

## Files Created/Modified

- `modules/system/impermanence.nix` — Mode enum rewritten, common block /tmp /var/tmp removed, btrfs lib.mkIf block added as third mkMerge entry, header updated

## Decisions Made

- **mode has no default:** Consistent with nerv.hostname and nerv.disko.layout — forces explicit declaration per host; prevents silent misconfiguration
- **/var/lib as single broad entry:** Covers nixos uid/gid allocations, systemd timers, sbctl keys, BT, NM, CUPS state in one entry — avoids a long explicit list that requires maintenance
- **/var/log absent from btrfs persistence:** The @log BTRFS subvolume (declared in disko.nix) handles log persistence. Adding /var/log here would create a double-mount conflict at stage-2 activation (v2.0 pre-phase decision)
- **sbctl warning not assertion:** Warning preserves nix flake check during multi-step migrations; sbctl key loss is recoverable (re-enrollment), unlike IMPL-02 scenario (tmpfs wipe) which uses a hard assertion
- **Static persistDirs list for warning:** Inspecting environment.persistence inside its own mkIf block causes self-reference evaluation cycle; the static list mirrors the locked persistence dirs in the same block

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected stale extraDirs description text**
- **Found during:** Task 1 (mode rewrite)
- **Issue:** `extraDirs` description said "Additive to the defaults (/tmp, /var/tmp)" — those defaults were removed in the same task, making the description incorrect
- **Fix:** Updated description to "Additional absolute system paths to mount as tmpfs." (removed stale reference)
- **Files modified:** modules/system/impermanence.nix
- **Verification:** Description now accurate to current behavior
- **Committed in:** 89c39ec (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — stale documentation text)
**Impact on plan:** Trivial inline correction, no scope change.

## Issues Encountered

- **nix not available on dev machine:** `nix flake check` and `nix eval` commands could not run (consistent with Phase 08 precedent). Structural verification performed via grep/file inspection:
  - `grep "minimal" impermanence.nix` → no results (correct)
  - `grep 'mode == "btrfs"' impermanence.nix` → btrfs block line found (correct)
  - `grep 'neededForBoot' impermanence.nix` → lines 112 and 138 (full and btrfs blocks)
  - `/var/log` absent from btrfs directories list (confirmed)
  - lib.mkMerge has 3 entries: common (line 81), full (line 103), btrfs (line 134)

- **Expected eval breakage:** `hostProfile` and `vmProfile` in flake.nix use `nerv.impermanence.mode = "minimal"` — this will now fail `nix flake check` with an enum type error. This is the intentional breaking change. Phase 12 updates those profiles to `mode = "btrfs"`.

## nix flake check Status

- **Nix unavailable on dev machine** — cannot run directly
- **Expected result when run on NixOS target:**
  - `server` nixosConfiguration (mode = "full") → PASS
  - `host` nixosConfiguration (mode = "minimal") → FAIL with type error: "minimal is not in [btrfs full]"
  - `vm` nixosConfiguration (mode = "minimal") → FAIL with same type error
  - This is the documented and expected breaking change (per plan success_criteria)

## Breaking Change Scope

The following nixosConfigurations in flake.nix need mode updated before `nix flake check` passes:

| Profile | Current mode | Required change | Who updates |
|---------|-------------|-----------------|-------------|
| hostProfile | "minimal" | "btrfs" | Phase 12 |
| vmProfile | "minimal" | "btrfs" or remove enable | Phase 12 |
| serverProfile | "full" | no change needed | — |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PERSIST-01 and PERSIST-02 requirements satisfied: btrfs impermanence mode module complete
- Phase 12 can now wire profiles: update hostProfile/vmProfile to mode = "btrfs" and add nerv.disko.layout declarations
- The btrfs persistence list (/var/lib, /etc/nixos, five files) is locked — Phase 12 profiles consume it as-is

---
*Phase: 11-impermanence-btrfs-mode*
*Completed: 2026-03-10*
