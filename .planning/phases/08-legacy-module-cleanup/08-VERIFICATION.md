---
phase: 08-legacy-module-cleanup
verified: 2026-03-08T16:41:48Z
status: passed
score: 7/7 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Push reachability — confirm NERV.nixos is publicly visible on GitHub"
    expected: "https://github.com/atirelli3/NERV.nixos shows 3+ commits, home/ hosts/ modules/ flake.nix present"
    why_human: "Cannot reach external GitHub URL from verifier. git -C /tmp/nerv-nixos remote -v shows origin configured; commits verified locally."
---

# Phase 8: NERV.nixos Release & Multi-Profile Migration — Verification Report

**Phase Goal:** Delete 9 dead flat modules, extend impermanence.nix for full server impermanence (/ as tmpfs + /persist), define host/server/vm profiles inline in flake.nix, clone NERV.nixos repo and migrate all refined work, reset test-nerv.nixos to commit cab4126e.
**Verified:** 2026-03-08T16:41:48Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | No flat .nix files in NERV.nixos modules/ root (only default.nix) | VERIFIED | `ls /tmp/nerv-nixos/modules/*.nix` returns only `modules/default.nix` |
| 2  | nerv.impermanence.mode option exists with enum [minimal full] default minimal | VERIFIED | Lines 43–53 of `modules/system/impermanence.nix`: `lib.types.enum [ "minimal" "full" ]`, `default = "minimal"` |
| 3  | Minimal mode behavior unchanged (/tmp and /var/tmp as tmpfs) | VERIFIED | Lines 94–105: `/tmp` and `/var/tmp` fileSystems inside the always-active mkMerge block |
| 4  | Full mode activates environment.persistence + fileSystems."/" as tmpfs | VERIFIED | Lines 110–139: `lib.mkIf (cfg.mode == "full")` block with `fileSystems."/"` (tmpfs), `fileSystems.persistPath.neededForBoot`, and `environment.persistence."${cfg.persistPath}"` |
| 5  | flake.nix defines hostProfile, serverProfile, vmProfile as inline let bindings; nixosConfigurations.host, .server, .vm defined | VERIFIED | Lines 35–74 (profiles) and lines 87–127 (nixosConfigurations.host, .server, .vm) in `/tmp/nerv-nixos/flake.nix` |
| 6  | nixosConfigurations.server includes impermanence.nixosModules.impermanence | VERIFIED | Line 106 of flake.nix: `impermanence.nixosModules.impermanence  # required for environment.persistence (mode = "full")` |
| 7  | hosts/configuration.nix is identity-only; NERV.nixos repo has complete structure; test-nerv.nixos HEAD is cab4126e | VERIFIED | configuration.nix has nerv.hostname, primaryUser, hardware, locale, stateVersion only — no service options. NERV.nixos has home/, hosts/, modules/, flake.nix. `git log --oneline -1` on test-nerv.nixos: `cab4126 base system` |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `/tmp/nerv-nixos/modules/default.nix` | Top-level aggregator — imports ./system ./services ../home | VERIFIED | File contains: `{ imports = [ ./system ./services ../home ]; }` |
| `/tmp/nerv-nixos/modules/system/impermanence.nix` | Extended impermanence module with mode option | VERIFIED | 142 lines; contains `nerv.impermanence.mode`, `environment.persistence`, full mode mkIf block |
| `/tmp/nerv-nixos/flake.nix` | impermanence flake input + three profiles + three nixosConfigurations | VERIFIED | 130 lines; `impermanence.url = "github:nix-community/impermanence"` present; hostProfile, serverProfile, vmProfile let bindings; nixosConfigurations.host/.server/.vm defined |
| `/tmp/nerv-nixos/hosts/configuration.nix` | Identity-only configuration | VERIFIED | 40 lines; nerv.hostname, nerv.primaryUser, nerv.hardware.*, nerv.locale.*, system.stateVersion, disko disk device; no service options |
| `/tmp/nerv-nixos/hosts/disko-configuration.nix` | Server disko layout with NIXPERSIST/NIXSTORE/NIXBOOT/NIXLUKS, no root LV | VERIFIED | 94 lines; NIXBOOT (1 occurrence), NIXLUKS (2), NIXSTORE (1), NIXPERSIST (1); no NIXROOT LV; `cryptroot`/`lvmroot` are LUKS/VG names only |
| `/tmp/nerv-nixos/hosts/hardware-configuration.nix` | Hardware placeholder file | VERIFIED | Present at `hosts/hardware-configuration.nix` |
| `/tmp/nerv-nixos/home/default.nix` | Home Manager wiring module | VERIFIED | Present; purpose comment confirms HM wiring |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `modules/default.nix` | `modules/system` and `modules/services` | `imports = [ ./system ./services ../home ]` | WIRED | Confirmed verbatim in file |
| `modules/system/impermanence.nix` | `environment.persistence` | `lib.mkIf (cfg.mode == "full")` | WIRED | Line 123: `environment.persistence."${cfg.persistPath}" = { ... }` |
| `flake.nix` | `impermanence.nixosModules.impermanence` | `impermanence.url` declaration + server modules list | WIRED | Input declared line 27; consumed in server modules list line 106 |
| `hosts/disko-configuration.nix` | `/persist` mountpoint | NIXPERSIST LVM logical volume | WIRED | `mountpoint = "/persist"` on NIXPERSIST LV |
| `flake.nix hostProfile` | `nixosConfigurations.host modules list` | `hostProfile` attrset in modules | WIRED | Line 93: `hostProfile` in host modules list |
| `flake.nix serverProfile` | `impermanence.nixosModules.impermanence` | server modules list entry | WIRED | Both `serverProfile` and `impermanence.nixosModules.impermanence` in server modules list |
| `hosts/configuration.nix` | `nerv.hostname` | direct option assignment | WIRED | Line 27: `nerv.hostname = "PLACEHOLDER";` |
| `test-nerv.nixos` | baseline commit cab4126e | `git reset --hard` | WIRED | `git log --oneline -1`: `cab4126 base system` |

### Requirements Coverage

The PLANs declare IMPL-04, IMPL-05, IMPL-06, and `dead-modules-cleanup`. Note: IMPL-04, IMPL-05, IMPL-06, and `dead-modules-cleanup` are **Phase 8 gap-closure IDs** — they do not appear as v1 entries in REQUIREMENTS.md (which lists IMPL-01 through IMPL-03 only). The ROADMAP.md notes: "Requirements: None (tech debt closure + graduation — no new v1.0 requirements). Gap Closure: Closes tech debt item A (dead modules). Adds IMPL-04 (full impermanence), IMPL-05 (multi-profile), IMPL-06 (repo migration)."

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| dead-modules-cleanup | 08-01-PLAN.md | 9 flat modules deleted from modules/ root | SATISFIED | Only `modules/default.nix` in NERV.nixos modules root; 9 named files absent |
| IMPL-04 | 08-02-PLAN.md | Full impermanence mode (/ as tmpfs + /persist via environment.persistence) | SATISFIED | `nerv.impermanence.mode` enum option present; full mode block with fileSystems."/" and environment.persistence verified |
| IMPL-05 | 08-03-PLAN.md | Inline profiles in flake.nix (host/server/vm) | SATISFIED | hostProfile, serverProfile, vmProfile let bindings + nixosConfigurations.host/.server/.vm all present |
| IMPL-06 | 08-04-PLAN.md | NERV.nixos repo migration + test repo reset | SATISFIED | NERV.nixos repo has 4 commits; test-nerv.nixos HEAD is cab4126e |

All 4 declared requirements satisfied. No orphaned requirements found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `hosts/configuration.nix` | 22, 27–35, 39 | `PLACEHOLDER` values | Info | Intentional user-fill markers — not a stub; comment instructs replacement before first boot |
| `hosts/disko-configuration.nix` | 61, 68, 74 | `SIZE_RAM * 2`, `SIZE` placeholder strings | Info | Intentional user-fill markers per design (DOCS-03 requirement) — warning header present |

No blocker or warning anti-patterns found. Both placeholder patterns are by design.

### Human Verification Required

#### 1. GitHub Push Reachability

**Test:** Visit https://github.com/atirelli3/NERV.nixos in a browser
**Expected:** Repository shows at least 3 commits: "first commit", "feat: initial NERV.nixos release — v1.0" (2c58d63), "docs: add project planning context" (d18d3f2), "docs(08-04): complete..." (7c3bc35). Structure shows home/, hosts/, modules/, flake.nix visible.
**Why human:** Cannot reach external URLs from verifier. Local clone at /tmp/nerv-nixos confirms all 4 commits and correct remote URL (`git@github.com:atirelli3/NERV.nixos.git`). Push success was confirmed by user during Plan 04 checkpoint.

### Notes

**nix flake check not executed:** The nix binary is not present on this development machine (non-NixOS Linux). Both SUMMARY.md files (08-01, 08-02) document this expected condition and confirm safety via import-chain analysis and grep verification. The structural wiring (imports, option declarations, module linkages) has been verified by direct file inspection and grep throughout this verification.

**NERV.nixos commit count:** The repo shows 4 commits (b38fc84 first commit, 2c58d63 release, d18d3f2 planning context, 7c3bc35 docs). The PLAN specified "at least one commit" — satisfied.

**server profile includes lanzaboote:** The Plan 03 interface notes specified: "vm omits lanzaboote (VMs don't use Secure Boot)". The actual flake.nix has server including `lanzaboote.nixosModules.lanzaboote` (serverProfile has `nerv.secureboot.enable = false` but lanzaboote module is still present). This matches the flake.nix written in Plan 03 verbatim — the Plan task deliberately included lanzaboote in server for symmetry with host. Not a gap.

---

_Verified: 2026-03-08T16:41:48Z_
_Verifier: Claude (gsd-verifier)_
