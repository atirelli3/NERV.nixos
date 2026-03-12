---
phase: 03-system-modules-non-boot
verified: 2026-03-07T09:44:09Z
status: human_needed
score: 9/10 must-haves verified
re_verification: false
human_verification:
  - test: "Run nixos-rebuild build --flake .#nixos-base on a NixOS machine"
    expected: "Build completes with exit 0, no evaluation errors, no attribute conflicts for users.users.demon0"
    why_human: "nix and nixos-rebuild are not installed on this development machine (Arch Linux). All three summaries document this limitation. Syntax and structural correctness verified manually. Actual NixOS module merge evaluation — including type checking of enum values, assertion evaluation, and cross-module wiring of nerv.zsh.enable into identity.nix's lib.optionalAttrs — requires a live Nix evaluator."
---

# Phase 3: System Modules (non-boot) Verification Report

**Phase Goal:** Identity, locale, primary user, and hardware options are exposed via the nerv.* API; hardware.nix, kernel.nix, security.nix, and nix.nix are in modules/system/
**Verified:** 2026-03-07T09:44:09Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 1  | A host flake can declare `nerv.hostname`, `nerv.locale.*` without editing any module file | VERIFIED | `modules/system/identity.nix` declares all four options with defaults; `configuration.nix` sets them via `nerv.*` API only |
| 2  | A host flake can declare `nerv.primaryUser` and have group membership wired automatically | VERIFIED | `identity.nix` line 66-72: `lib.genAttrs config.nerv.primaryUser` assigns `wheel+networkmanager` groups; `lib.optionalAttrs config.nerv.zsh.enable` sets `shell = pkgs.zsh` |
| 3  | Setting `nerv.hardware.cpu = "amd"` or `"intel"` enables correct microcode and CPU-specific kernel params; `"other"` applies neither | VERIFIED | `hardware.nix` lines 49-56: `lib.mkIf (cfg.cpu == "amd")` sets `hardware.cpu.amd.updateMicrocode = true` and `boot.kernelParams = ["amd_iommu=on" "iommu=pt"]`; intel branch mirrors for intel; no "other" branch = no emission |
| 4  | Setting `nerv.hardware.gpu = "amd"/"nvidia"/"intel"/"none"` enables or disables appropriate GPU drivers | VERIFIED | `hardware.nix` lines 59-71: three `lib.mkIf` branches cover nvidia (`videoDrivers = ["nvidia"]`, `nvidia.open = true`), amd (`amdgpu`), intel (`intel`); "none" emits nothing |
| 5  | `nixos-rebuild build --flake .#nixos-base` succeeds with no evaluation errors | UNCERTAIN | Nix not installed on dev machine. Module structure, import graph, and wiring are correct by static analysis. Requires live evaluation — see Human Verification. |

Additional truths from plan must_haves (Plans 01, 02, 03):

| #  | Truth | Status | Evidence |
|----|-------|--------|---------|
| 6  | `modules/system/default.nix` imports identity.nix, hardware.nix, kernel.nix, security.nix, and nix.nix | VERIFIED | `default.nix` lines 3-9: all five imports present, no extras |
| 7  | `hosts/nixos-base/configuration.nix` uses nerv.* API for all identity and hardware declarations | VERIFIED | Lines 48-54: `nerv.hostname`, `nerv.locale.*` (3 options), `nerv.primaryUser`, `nerv.hardware.cpu`, `nerv.hardware.gpu` all declared; no inline `time.timeZone`, `i18n.defaultLocale`, `console = {...}`, or `networking.hostName` |
| 8  | `kernel.nix` contains no CPU-specific IOMMU params in executable code | VERIFIED | grep confirms `amd_iommu` appears only in line 5 header comment (note text), not in any executable Nix expression |
| 9  | `modules/system/nix.nix` uses `/etc/nerv#nixos-base` (stale `/etc/nixos#nixos` removed) | VERIFIED | `nix.nix` line 18: `flake = "/etc/nerv#nixos-base";` — confirmed present; old path absent from active module |
| 10 | `security.nix` content is in `modules/system/` with all hardening active | VERIFIED | `security.nix` 121 lines: AppArmor (`security.apparmor.enable`), auditd (`security.auditd.enable` + 8 audit rules), ClamAV (`services.clamav.daemon.enable` + `updater.enable`), AIDE (config + systemd service + timer) all present |

**Score:** 9/10 truths verified (truth #5 deferred to human verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `modules/system/identity.nix` | nerv.hostname, nerv.locale.*, nerv.primaryUser options and config wiring | VERIFIED | 75 lines; all 5 options declared with correct types; `lib.mkMerge` config with always-on fragment and `lib.mkIf` primaryUser fragment |
| `modules/system/hardware.nix` | nerv.hardware.cpu and nerv.hardware.gpu enum options with conditional microcode, IOMMU params, GPU drivers | VERIFIED | 74 lines; cpu enum `[amd intel other]` default `"other"`; gpu enum `[amd nvidia intel none]` default `"none"`; `lib.mkMerge` with 5 conditional branches |
| `modules/system/kernel.nix` | Generic kernel hardening params, no CPU-specific IOMMU lines | VERIFIED | 103 lines; zen kernel, 9 boot.kernelParams, full sysctl hardening (12 network + 7 kernel + 3 memory + 4 filesystem entries), blacklistedKernelModules; IOMMU params absent from executable code |
| `modules/system/security.nix` | Opaque security hardening (AppArmor, auditd, ClamAV, AIDE) | VERIFIED | 121 lines; all four hardening components fully configured and active |
| `modules/system/nix.nix` | Nix daemon config with corrected autoUpgrade flake path | VERIFIED | 59 lines; `/etc/nerv#nixos-base` confirmed; GC, optimise, autoUpgrade, allowed/trusted users all present |
| `modules/system/default.nix` | System module aggregator importing all five system modules | VERIFIED | 10 lines; imports `[./identity.nix ./hardware.nix ./kernel.nix ./security.nix ./nix.nix]` exactly as specified |
| `hosts/nixos-base/configuration.nix` | Host config using nerv.* API for identity and hardware | VERIFIED | 68 lines; all 7 nerv.* identity/hardware declarations present; all stale inline options removed; `users.users.demon0 = { isNormalUser = true; }` only |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `modules/system/identity.nix` | `networking.hostName` | `config.nerv.hostname` | WIRED | Line 56: `networking.hostName = config.nerv.hostname;` |
| `modules/system/identity.nix` | `users.users` | `lib.genAttrs cfg.primaryUser` | WIRED | Line 67: `users.users = lib.genAttrs config.nerv.primaryUser (...)` |
| `modules/system/hardware.nix` | `hardware.cpu.amd.updateMicrocode` | `lib.mkIf (cfg.cpu == "amd")` | WIRED | Line 49-51: conditional present and correct |
| `modules/system/hardware.nix` | `services.xserver.videoDrivers` | `lib.mkIf (cfg.gpu == ...)` | WIRED | Lines 59-70: three GPU branches all wired |
| `modules/system/default.nix` | `modules/system/identity.nix` | `./identity.nix` import | WIRED | Line 4: `./identity.nix` in imports list |
| `hosts/nixos-base/configuration.nix` | `nerv.hostname` | `nerv.hostname = "nixos-base"` | WIRED | Line 48: declaration present |
| `modules/system/nix.nix` | `/etc/nerv#nixos-base` | `system.autoUpgrade.flake` | WIRED | Line 18: `flake = "/etc/nerv#nixos-base";` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| OPT-01 | 03-01, 03-03 | User can set `nerv.hostname`, `nerv.locale.timeZone`, `nerv.locale.keyMap`, `nerv.locale.defaultLocale` | SATISFIED | `identity.nix` declares all four options; `configuration.nix` uses all four |
| OPT-02 | 03-01, 03-03 | User can set `nerv.primaryUser` to declare primary system user with group membership | SATISFIED | `identity.nix` `lib.genAttrs` wires `wheel+networkmanager`; `configuration.nix` sets `nerv.primaryUser = ["demon0"]` |
| OPT-03 | 03-02, 03-03 | User can set `nerv.hardware.cpu` (enum: amd/intel/other) for microcode and kernel params | SATISFIED | `hardware.nix` enum option with conditional `lib.mkIf` branches for amd and intel; `configuration.nix` sets `nerv.hardware.cpu = "amd"` |
| OPT-04 | 03-02, 03-03 | User can set `nerv.hardware.gpu` (enum: amd/nvidia/intel/none) for GPU drivers | SATISFIED | `hardware.nix` enum option with three `lib.mkIf` GPU driver branches; `configuration.nix` sets `nerv.hardware.gpu = "none"` |

All four Phase 3 requirements (OPT-01 through OPT-04) are satisfied by static analysis. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `modules/hardware.nix` (old flat) | — | Stale file not cleaned up | Info | Old flat `modules/hardware.nix`, `modules/kernel.nix`, `modules/security.nix`, `modules/nix.nix` still exist in repo root. They are NOT imported (modules/default.nix only imports `./system ./services ../home`). No functional impact — but these are dead code that could confuse future contributors. |
| `modules/zsh.nix` (old flat) | 69-71 | Stale `/etc/nixos#nixos` aliases | Info | Old `modules/zsh.nix` contains stale shell aliases pointing to `/etc/nixos#nixos`. Not imported — active `modules/services/zsh.nix` has correct `/etc/nerv#nixos-base` aliases. No functional impact. |

No blocker or warning anti-patterns found in the new Phase 3 files.

### Human Verification Required

#### 1. Full NixOS Build

**Test:** On the target NixOS machine (or any machine with nix installed), from the repo root run: `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
**Expected:** Build completes with exit 0. No evaluation errors. The resulting system closure includes all five system modules (identity, hardware, kernel, security, nix) wired under modules/system/. No attribute conflict on `users.users.demon0` (identity.nix sets `extraGroups` via `lib.genAttrs`; configuration.nix sets only `isNormalUser = true` — these should merge cleanly via NixOS module system).
**Why human:** nix and nixos-rebuild are not installed on this Arch Linux development machine. All three plan summaries document this limitation. Static structural analysis confirms correct Nix syntax (brace balance, option type declarations, lib.mkMerge/lib.mkIf usage), correct import graph, and correct content. However, actual NixOS module evaluation — type checking enum strings, resolving cross-module references to `config.nerv.zsh.enable` in identity.nix, evaluating assertions, and merging all module configs — requires a live Nix evaluator.

### Gaps Summary

No gaps found. All seven required artifacts exist with substantive content and are correctly wired. All four requirement IDs (OPT-01 through OPT-04) are satisfied. No blocker anti-patterns exist in Phase 3 files. The only uncertainty is the live build test, which cannot be executed on the development machine.

---

_Verified: 2026-03-07T09:44:09Z_
_Verifier: Claude (gsd-verifier)_
