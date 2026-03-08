---
phase: 01-flake-foundation
verified: 2026-03-06T22:45:00Z
status: human_needed
score: 6/8 truths verified (2 require nix CLI on NixOS machine)
re_verification:
  previous_status: human_needed
  previous_score: 2/4
  gaps_closed:
    - "hosts/nixos-base/ exists with all three config files (configuration.nix, disko-configuration.nix, hardware-configuration.nix)"
    - "base/ directory removed from repo"
    - "flake.nix nixosConfigurations.nixos-base references ./hosts/nixos-base/configuration.nix via self.nixosModules.default"
    - "nixosConfigurations.nixos-base defined in root flake.nix using self references (not sub-flake)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run `nix flake show` from /etc/nerv (or the repo root) and confirm all four nixosModules exports plus nixosConfigurations.nixos-base appear"
    expected: "Output lists nixosModules.default, nixosModules.system, nixosModules.services, nixosModules.home, and nixosConfigurations.nixos-base"
    why_human: "nix CLI is not installed on the Arch Linux development machine (crysis). Static analysis confirms all four exports and the nixosConfigurations block are declared correctly in flake.nix, but only nix evaluation confirms the import ./modules chain and ./hosts/nixos-base/configuration.nix path resolve without errors."
  - test: "Run `nixos-rebuild build --flake /etc/nerv#nixos-base` on the NixOS machine"
    expected: "Command exits 0 with no evaluation errors"
    why_human: "nixos-rebuild requires the nix CLI and a full NixOS environment. All wiring is statically correct (flake.nix uses self.nixosModules.default and ./hosts/nixos-base/configuration.nix; hardware-configuration.nix placeholder evaluates as { ... }: {}). The real hardware-configuration.nix must also be substituted before the build will succeed on real hardware."
---

# Phase 1: Flake Foundation Verification Report

**Phase Goal:** The flake.nix correctly declares all required inputs and exports named nixosModules; the target directory structure exists (hosts/nixos-base/ with configuration.nix, hardware-configuration.nix, disko-configuration.nix); nixosConfigurations.nixos-base defined in root flake.nix using self references; base/ directory removed.
**Verified:** 2026-03-06T22:45:00Z
**Status:** HUMAN_NEEDED — all automated checks pass for both plans; two items require a machine with the nix CLI
**Re-verification:** Yes — after Plan 02 (host directory rename) completion; previous verification covered Plan 01 only

---

## Goal Achievement

Both plans executed and committed. The phase goal as stated is now fully reflected in the codebase — verified item by item below.

### Observable Truths

| # | Truth | Source Plan | Status | Evidence |
|---|-------|-------------|--------|----------|
| 1 | `nix flake show` lists nixosModules.default, .system, .services, and .home | 01-01 | ? HUMAN NEEDED | flake.nix lines 27-34 declare all four exports with `import ./path`; nix CLI unavailable on dev machine |
| 2 | flake.nix declares home-manager and impermanence with `inputs.nixpkgs.follows = "nixpkgs"` on both | 01-01 | VERIFIED | flake.nix lines 14-23: both inputs present with `inputs.nixpkgs.follows = "nixpkgs"` on each |
| 3 | modules/system/, modules/services/, and home/ each contain a stub default.nix with `{ imports = []; }` | 01-01 | VERIFIED | All three files confirmed — exact content `{ imports = []; }` with phase comment |
| 4 | hosts/nixos-base/ directory exists with configuration.nix, hardware-configuration.nix, and disko-configuration.nix | 01-02 | VERIFIED | `ls hosts/nixos-base/` returns all three files; committed in 56b9402 and 07dd4be |
| 5 | base/ directory is removed from the repo | 01-02 | VERIFIED | `test -d base/` fails; base/ not present at repo root; git rm confirmed in 56b9402 |
| 6 | flake.nix nixosConfigurations.nixos-base references ./hosts/nixos-base/configuration.nix | 01-02 | VERIFIED | flake.nix lines 36-42: `nixosConfigurations.nixos-base` block with `./hosts/nixos-base/configuration.nix` |
| 7 | nixosConfigurations.nixos-base uses self.nixosModules.default (not sub-flake path:.. reference) | 01-02 (fix cb35bd9) | VERIFIED | flake.nix line 39: `self.nixosModules.default` — self-referential, no cross-flake path |
| 8 | `nixos-rebuild build --flake /etc/nerv#nixos-base` succeeds without evaluation errors | 01-02 | ? HUMAN NEEDED | Requires nix CLI + NixOS machine; all static wiring is correct; hardware-configuration.nix placeholder must be replaced on target machine |

**Score:** 6/8 truths verified programmatically; 2 need human (nix CLI unavailable); 0 failed

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `flake.nix` | Library root — nixosModules exports + nixosConfigurations.nixos-base | VERIFIED | 44 lines; all four nixosModules declared; nixosConfigurations.nixos-base defined with self.nixosModules.default and ./hosts/nixos-base/configuration.nix |
| `modules/default.nix` | Aggregator importing system, services, and home stubs | VERIFIED | `{ imports = [ ./system ./services ../home ]; }` — exact spec match |
| `modules/system/default.nix` | Empty system module stub | VERIFIED | `{ imports = []; }` with Phase 3 comment |
| `modules/services/default.nix` | Empty services module stub | VERIFIED | `{ imports = []; }` with Phase 2 comment |
| `home/default.nix` | Empty home module stub | VERIFIED | `{ imports = []; }` with Phase 5 comment |
| `hosts/nixos-base/configuration.nix` | Host machine NixOS config (moved from base/) | VERIFIED | 65 lines; substantive host config (networking, boot, filesystems, users, locale); git mv preserved history |
| `hosts/nixos-base/disko-configuration.nix` | Disko disk layout (moved from base/) | VERIFIED | 60 lines; full GPT + LUKS + LVM layout; git mv preserved history |
| `hosts/nixos-base/hardware-configuration.nix` | Hardware config placeholder (real file needed on NixOS machine) | VERIFIED | Placeholder with clear instructions: `{ ... }: { }` — valid Nix, will not cause evaluation errors |

All 8 artifacts: EXISTS and SUBSTANTIVE. Wiring verified below.

Note: `base/flake.nix` from Plan 01 no longer exists — it was superseded and removed in Plan 02 (56b9402). The nixosConfigurations that were previously in base/flake.nix are now in root flake.nix using `self.nixosModules.default` (fix commit cb35bd9).

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `flake.nix` | `modules/default.nix` | `import ./modules` | WIRED | flake.nix line 29: `default = import ./modules;` |
| `flake.nix` | `modules/system/default.nix` | `import ./modules/system` | WIRED | flake.nix line 31: `system = import ./modules/system;` |
| `flake.nix` | `modules/services/default.nix` | `import ./modules/services` | WIRED | flake.nix line 32: `services = import ./modules/services;` |
| `flake.nix` | `home/default.nix` | `import ./home` | WIRED | flake.nix line 33: `home = import ./home;` |
| `modules/default.nix` | `modules/system, modules/services, home` | imports list | WIRED | `{ imports = [ ./system ./services ../home ]; }` |
| `flake.nix` | `hosts/nixos-base/configuration.nix` | nixosConfigurations.nixos-base modules list | WIRED | flake.nix line 40: `./hosts/nixos-base/configuration.nix` |
| `flake.nix` | `self.nixosModules.default` | self reference in nixosConfigurations | WIRED | flake.nix line 39: `self.nixosModules.default` — avoids cross-flake path:.. resolution issues |

All 7 key links: WIRED.

**Architectural note:** The original Plan 01 wired `base/flake.nix → flake.nix` via `inputs.nerv.url = "path:.."`. This was replaced in commit cb35bd9 and Plan 02 because `path:..` fails under pure eval when `/etc/nerv` is a nix store symlink. The final architecture consolidates nixosConfigurations into the root flake using `self.nixosModules.default`, which is the correct NixOS pattern and eliminates the sub-flake entirely.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| STRUCT-01 | 01-01-PLAN.md, 01-02-PLAN.md | Repository reorganized into modules/system/ and modules/services/ subdirectories with default.nix aggregators in each | SATISFIED | modules/system/default.nix and modules/services/default.nix exist; directory hierarchy confirmed; hosts/nixos-base/ convention established for host configs |
| STRUCT-04 | 01-01-PLAN.md, 01-02-PLAN.md | Root flake.nix exports nixosModules.default, .system, .services, and .home for external host flake consumption | SATISFIED (static) | All four named exports declared in flake.nix outputs.nixosModules; nixosConfigurations.nixos-base present using self reference; `nix flake show` needed to confirm evaluation |
| STRUCT-05 | 01-01-PLAN.md | flake.nix includes home-manager and impermanence as inputs with inputs.nixpkgs.follows = "nixpkgs" | SATISFIED | Both confirmed in flake.nix lines 14-23 with correct nixpkgs.follows on each |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps only STRUCT-01, STRUCT-04, STRUCT-05 to Phase 1. No additional Phase 1 requirements exist. All three claimed IDs are accounted for in both plans' `requirements` fields.

**REQUIREMENTS.md checkbox status:** STRUCT-01 [x], STRUCT-04 [x], STRUCT-05 [x] — all marked complete, consistent with both SUMMARYs.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `modules/system/default.nix` | 2 | `{ imports = []; }` — empty stub | INFO | Intentional; documented placeholder for Phase 3 |
| `modules/services/default.nix` | 2 | `{ imports = []; }` — empty stub | INFO | Intentional; documented placeholder for Phase 2 |
| `home/default.nix` | 2 | `{ imports = []; }` — empty stub | INFO | Intentional; documented placeholder for Phase 5 |
| `hosts/nixos-base/hardware-configuration.nix` | 1-3 | Placeholder — `{ ... }: { }` | INFO | Required by plan; dev machine has no /etc/nixos/; must be replaced on NixOS machine before deployment |
| `hosts/nixos-base/disko-configuration.nix` | 4 | `/dev/DISK` placeholder | INFO | Pre-existing; documented in file; not introduced by Phase 1 |
| `hosts/nixos-base/disko-configuration.nix` | 42 | `SIZE_RAM * 2` placeholder | INFO | Pre-existing; documented in file; not introduced by Phase 1 |

No TODO/FIXME strings. Empty stubs and placeholders are all by design and explicitly documented. No blockers.

**Flat modules confirmed untouched:** bluetooth.nix, hardware.nix, kernel.nix, nix.nix, openssh.nix, pipewire.nix, printing.nix, secureboot.nix, security.nix, zsh.nix — all 10 present in modules/, none referenced or modified by either Phase 1 plan.

---

## Human Verification Required

### 1. nix flake show — nixosModules and nixosConfigurations export evaluation

**Test:** From `/etc/nerv` (repo deployed on NixOS machine), run:
```bash
nix flake show 2>&1 | grep -E 'nixosModules\.(default|system|services|home)|nixosConfigurations\.nixos-base'
```
**Expected:** Five lines appear — one for each of nixosModules.default, nixosModules.system, nixosModules.services, nixosModules.home, and nixosConfigurations.nixos-base
**Why human:** nix CLI is not installed on the Arch Linux development machine. Static analysis confirms all exports are declared correctly, but only nix evaluation confirms the `import ./modules` chain and `./hosts/nixos-base/configuration.nix` path resolve without errors.

### 2. nixos-rebuild build — end-to-end host evaluation

**Test:** From the NixOS machine with repo at `/etc/nerv`, run:
```bash
nixos-rebuild build --flake /etc/nerv#nixos-base
```
Note: hardware-configuration.nix must be replaced with real output of `nixos-generate-config --show-hardware-config` before this can succeed on real hardware.
**Expected:** Command exits 0 with no evaluation errors
**Why human:** Requires nix CLI and a NixOS environment. All static wiring is correct: flake.nix uses `self.nixosModules.default` and `./hosts/nixos-base/configuration.nix`; the module chain resolves through modules/default.nix to the three stub aggregators; the hardware-configuration.nix placeholder is valid Nix (`{ ... }: { }`).

---

## Commits Verified

Both plans executed atomically, all commits confirmed in git history:

| Commit | Plan | Description |
|--------|------|-------------|
| 9491f6d | 01-01 Task 1 | Create root flake.nix and module stub files |
| 1948f06 | 01-01 Task 2 | Rewrite base/flake.nix to consume nerv library via path:.. |
| cb35bd9 | 01-01 Fix | Move nixosConfigurations to root flake (self reference, not sub-flake) |
| 56b9402 | 01-02 Task 1 | Move base/ to hosts/nixos-base/ and update flake.nix |
| 07dd4be | 01-02 Task 2 | Add hardware-configuration.nix placeholder |

---

## Gaps Summary

No gaps found. All 8 artifacts exist, are substantive, and are wired correctly. All 7 key links are confirmed present. All 3 requirement IDs (STRUCT-01, STRUCT-04, STRUCT-05) are satisfied by the static evidence.

The two human verification items are not gaps — the nix CLI is unavailable on the dev machine, which is a known environmental constraint documented in both SUMMARYs. The static structure is complete and correct; human verification is needed only to confirm the Nix evaluator agrees at runtime.

**Phase goal achievement:** All four elements of the phase goal are confirmed:
1. flake.nix correctly declares all required inputs (nixpkgs, lanzaboote, home-manager, impermanence) and exports named nixosModules — VERIFIED
2. Target directory structure exists: hosts/nixos-base/ with configuration.nix, hardware-configuration.nix, disko-configuration.nix — VERIFIED
3. nixosConfigurations.nixos-base defined in root flake.nix using self.nixosModules.default (self reference) — VERIFIED
4. base/ directory removed — VERIFIED

---

_Verified: 2026-03-06T22:45:00Z_
_Verifier: Claude (gsd-verifier)_
_Plans covered: 01-01 (flake foundation) + 01-02 (host directory rename)_
