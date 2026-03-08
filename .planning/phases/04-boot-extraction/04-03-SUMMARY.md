---
phase: 04-boot-extraction
plan: "03"
subsystem: system-modules
tags: [secureboot, lanzaboote, tpm2, luks, aggregator, wiring, phase-complete]
dependency_graph:
  requires: [04-01, 04-02]
  provides: [STRUCT-02, IMPL-01, IMPL-02, IMPL-03]
  affects: [modules/system/default.nix, hosts/nixos-base/configuration.nix]
tech_stack:
  added: [lanzaboote, tpm2-tss, sbctl]
  patterns: [options-config-mkIf, opaque-module, last-import-ordering]
key_files:
  created:
    - modules/system/secureboot.nix
  modified:
    - modules/system/default.nix
    - hosts/nixos-base/configuration.nix
  deleted:
    - modules/secureboot.nix
decisions:
  - "modules/secureboot.nix deleted after migration — flat unconditional file would apply secureboot to all hosts without the enable guard"
  - "luks-cryptenroll let binding moved inside config = lib.mkIf block as local let — preserves scoping while respecting the enable guard"
  - "NIXLUKS string hardcodes use let luksDevice01 bindings in secureboot-enroll-tpm2 and luks-cryptenroll — cross-reference comment on each binding"
metrics:
  duration: "~15 minutes"
  completed: "2026-03-07"
  tasks_completed: 2
  files_modified: 3
---

# Phase 4 Plan 3: Secureboot Wire-up and Phase Completion Summary

**One-liner:** Migrated modules/secureboot.nix into modules/system/secureboot.nix with nerv.secureboot.enable guard via lib.mkIf, wired all three new modules into the system aggregator, removed the boot block from configuration.nix, and deleted the old flat unconditional secureboot file to complete Phase 4.

## What Was Built

Phase 4 — Boot Extraction — is now complete. All four requirements (STRUCT-02, IMPL-01, IMPL-02, IMPL-03) are satisfied:

- **modules/system/secureboot.nix** — New guarded module. Declares `options.nerv.secureboot.enable` and wraps all Lanzaboote + TPM2 configuration in `config = lib.mkIf cfg.enable`. All three NIXLUKS string hardcodes carry cross-reference comments pointing to `disko-configuration.nix` and `boot.nix`.

- **modules/system/default.nix** — Updated aggregator now imports `./boot.nix`, `./impermanence.nix`, and `./secureboot.nix` (last, as required by the mkForce ordering constraint). The "non-boot" caveat in the comment is removed.

- **hosts/nixos-base/configuration.nix** — Boot block (lines 25–41) removed. The host config now contains only hardware-configuration import, networking, fileSystems, swapDevices, users, system.stateVersion, and nerv.* options. Boot is fully owned by boot.nix via the aggregator.

- **modules/secureboot.nix** — Deleted. The flat unconditional file no longer exists; the guarded replacement in modules/system/secureboot.nix is the sole source of secureboot configuration.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create modules/system/secureboot.nix | c93aae5 | modules/system/secureboot.nix (created) |
| 2 | Wire aggregator, remove boot block, delete old secureboot.nix | 28f7299 | modules/system/default.nix, hosts/nixos-base/configuration.nix (modified), modules/secureboot.nix (deleted) |

## Verification Results

- `ls modules/system/` — boot.nix, impermanence.nix, secureboot.nix present alongside existing modules: PASS
- `ls modules/secureboot.nix` — "No such file or directory": PASS
- `grep "boot\." hosts/nixos-base/configuration.nix` — None found: PASS
- `grep "secureboot.nix" modules/system/default.nix` — Import line present: PASS
- NIXLUKS cross-reference comments — All three occurrences (header + 2 let bindings) annotated: PASS
- `nixos-rebuild build` / `nix flake check` — Not available on dev machine (no Nix installed); structural verification passed; full build must be confirmed on NixOS host

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Adaptation] luks-cryptenroll moved into environment.systemPackages local let**

- **Found during:** Task 1
- **Issue:** The original modules/secureboot.nix defined `luks-cryptenroll` as a top-level let binding. Moving it verbatim into `config = lib.mkIf cfg.enable` required it to become a local let inside the config attribute, since the top-level let is outside the mkIf scope.
- **Fix:** Defined `luks-cryptenroll` as a local let inside `environment.systemPackages = let ... in [...]` — semantically identical, correctly scoped under the enable guard.
- **Files modified:** modules/system/secureboot.nix
- **Commit:** c93aae5

### Build Verification Limitation

`nixos-rebuild build` and `nix flake check` could not be executed — the development machine does not have Nix installed. All structural invariants were verified manually:
- File existence
- Import wiring
- No boot.* in configuration.nix
- NIXLUKS cross-reference comments
- Module structure (options + config = lib.mkIf)

Full build verification must be performed on the target NixOS host before `nerv.secureboot.enable = true` is set.

## Phase 4 Completion

Phase 4 — Boot Extraction — is complete:

| Requirement | Description | Status |
|-------------|-------------|--------|
| STRUCT-02 | boot.nix exists in modules/system/ | Done (04-01) |
| IMPL-01 | impermanence.nix declares nerv.impermanence.enable | Done (04-02) |
| IMPL-02 | sbctl persistence wired in impermanence.nix | Done (04-02) |
| IMPL-03 | Per-user custom mounts (extraPersistentDirs) | Done (04-02) |

All four requirements satisfied. Boot config is extracted, impermanence module is available (disabled by default), secureboot is wired last with enable guard.
