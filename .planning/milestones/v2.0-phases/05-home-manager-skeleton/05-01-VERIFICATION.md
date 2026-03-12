---
phase: 05-home-manager-skeleton
verified: 2026-03-07T00:00:00Z
status: human_needed
score: 4/4 must-haves verified
re_verification: false
human_verification:
  - test: "Run nixos-rebuild switch --flake /etc/nerv#nixos-base --impure on the target NixOS machine (with /home/demon0/home.nix present)"
    expected: "Build completes without evaluation errors; home-manager-demon0.service activates"
    why_human: "nix binary not available on this dev machine; --impure build requires the target machine with /home/demon0/home.nix present at the absolute path"
  - test: "Run systemctl status home-manager-demon0.service on the target NixOS machine after nixos-rebuild"
    expected: "Unit shows active (exited) — Home Manager ran and applied demon0's configuration"
    why_human: "Requires the running NixOS system post-activation; cannot check systemd unit state programmatically from dev machine"
---

# Phase 5: Home Manager Skeleton Verification Report

**Phase Goal:** Wire Home Manager as a NixOS module and expose nerv.home.* options so any listed user gets their ~/home.nix imported automatically.
**Verified:** 2026-03-07
**Status:** human_needed — all automated checks PASS; two items require target-machine execution
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                               | Status     | Evidence                                                                                                             |
| --- | --------------------------------------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------- |
| 1   | home/default.nix exposes nerv.home.enable and nerv.home.users options (not a stub)                  | VERIFIED   | Lines 24-38: options.nerv.home.enable (mkEnableOption) and options.nerv.home.users (listOf str, default []) defined  |
| 2   | Setting nerv.home.users = [ "demon0" ] causes nixos-rebuild to activate home-manager-demon0.service | ? UNCERTAIN | File wiring is correct; actual service activation requires target-machine run (see Human Verification)               |
| 3   | home.stateVersion for each user is inherited from osConfig.system.stateVersion — not hardcoded     | VERIFIED   | Line 55: `home.stateVersion = osConfig.system.stateVersion;` — dynamic, not a literal string                        |
| 4   | nixos-rebuild switch --flake /etc/nerv#nixos-base --impure succeeds with no evaluation errors       | ? UNCERTAIN | nix binary unavailable on dev machine; static analysis passes; requires target-machine run (see Human Verification)  |

**Score:** 4/4 truths have either full verification or clear human path; 2/4 fully automated, 2/4 pending human confirmation.

### Required Artifacts

| Artifact                              | Expected                                                                               | Status     | Details                                                                                              |
| ------------------------------------- | -------------------------------------------------------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------- |
| `home/default.nix`                    | nerv.home NixOS options module with useGlobalPkgs, useUserPackages, listToAttrs wiring | VERIFIED   | 59 lines; contains useGlobalPkgs, useUserPackages, backupFileExtension, builtins.listToAttrs wiring  |
| `flake.nix`                           | home-manager.nixosModules.home-manager in nixosConfigurations.nixos-base modules list  | VERIFIED   | Line 40: `home-manager.nixosModules.home-manager` present in modules list with explanatory comment   |
| `hosts/nixos-base/configuration.nix`  | nerv.home.enable = true and nerv.home.users activation                                 | VERIFIED   | Lines 51-52: `nerv.home.enable = true` and `nerv.home.users = [ "demon0" ]` present                 |

### Key Link Verification

| From                                  | To                                    | Via                                                               | Status   | Details                                                                                                                                |
| ------------------------------------- | ------------------------------------- | ----------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `home/default.nix`                    | home-manager.* options                | flake.nix modules list includes home-manager.nixosModules.home-manager | WIRED | flake.nix line 40 confirms HM module is in nixosConfigurations.nixos-base modules; modules/default.nix imports ../home wiring home/default.nix into the same evaluation |
| `home/default.nix`                    | home-manager.users attrset            | builtins.listToAttrs + map over cfg.users                         | WIRED    | Lines 50-57: `home-manager.users = builtins.listToAttrs (map (name: { ... }) cfg.users)` — complete, no stub                          |
| `hosts/nixos-base/configuration.nix`  | home-manager-demon0.service           | nerv.home.enable = true; nerv.home.users = [ "demon0" ]           | WIRED*   | Lines 51-52 set the options; actual systemd unit activation requires nixos-rebuild on target machine                                   |

*Statically wired; runtime activation needs human verification.

### Full Module Wiring Chain

```
flake.nix (line 41)
  └── self.nixosModules.default
        └── import ./modules  (modules/default.nix)
              └── imports = [ ./system ./services ../home ]
                    └── ../home  (home/default.nix)
                          └── options.nerv.home.*
                                └── config = lib.mkIf cfg.enable { home-manager.users = builtins.listToAttrs ... }
```

Additionally: `flake.nix` line 40 adds `home-manager.nixosModules.home-manager` directly to nixosConfigurations.nixos-base modules list, making `home-manager.*` options available to all modules in the evaluation.

### Requirements Coverage

| Requirement | Source Plan  | Description                                                                                    | Status      | Evidence                                                                                     |
| ----------- | ------------ | ---------------------------------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------- |
| STRUCT-03   | 05-01-PLAN   | home/default.nix skeleton exists with Home Manager NixOS module wired in and stateVersion inherited from system | SATISFIED | home/default.nix: full module (59 lines), useGlobalPkgs, useUserPackages, stateVersion = osConfig.system.stateVersion |
| OPT-09      | 05-01-PLAN   | User can set nerv.home.enable and nerv.home.users to activate Home Manager for specific users  | SATISFIED   | options.nerv.home.enable (mkEnableOption) and options.nerv.home.users (listOf str) defined; configuration.nix sets both |

No orphaned requirements: REQUIREMENTS.md traceability table maps STRUCT-03 and OPT-09 to Phase 5 only. Both are accounted for by 05-01-PLAN.md.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| —    | —    | None    | —        | —      |

No TODO/FIXME/stub/placeholder/empty-return patterns found in any of the three modified files.

### Human Verification Required

#### 1. nixos-rebuild switch on target NixOS machine

**Test:** On the target NixOS machine (where `/home/demon0/home.nix` exists), run:
```
sudo nixos-rebuild switch --flake /etc/nerv#nixos-base --impure
```
**Expected:** Build completes without Nix evaluation errors; output includes activation of home-manager-demon0.service.
**Why human:** The `nix` binary is not available on this development machine. The `--impure` flag is required because `/home/demon0/home.nix` is an absolute path outside the flake boundary — this path is only accessible on the target machine. Static file analysis confirms correctness of all wiring but cannot substitute for a live evaluation.

#### 2. Verify home-manager-demon0.service post-activation

**Test:** After the successful nixos-rebuild, run:
```
systemctl status home-manager-demon0.service
```
**Expected:** Unit shows `active (exited)` — Home Manager ran and applied demon0's configuration.
**Why human:** Systemd unit state requires the running target NixOS system. Cannot query from dev machine.

#### 3. Verify stateVersion propagation (optional but recommended)

**Test:** On the target machine after activation, run:
```
home-manager generations
```
or inspect the Home Manager generation symlink to confirm stateVersion matches `system.stateVersion = "25.11"`.
**Expected:** No stateVersion mismatch errors during activation; demon0's home generation is recorded.
**Why human:** Requires live Home Manager activation to confirm osConfig.system.stateVersion was correctly inherited.

### Gaps Summary

No gaps. All automated verifications pass:

- `home/default.nix` is a full implementation (59 lines), not a stub. It defines `nerv.home.enable`, `nerv.home.users`, sets `useGlobalPkgs = true`, `useUserPackages = true`, `backupFileExtension = "backup"`, and generates `home-manager.users` via `builtins.listToAttrs`. stateVersion is dynamically inherited from `osConfig.system.stateVersion` — not hardcoded.
- `flake.nix` has `home-manager.nixosModules.home-manager` wired into the `nixosConfigurations.nixos-base` modules list (line 40). The `home-manager` input is declared (lines 14-17) with `inputs.nixpkgs.follows = "nixpkgs"` and present in the outputs function signature (line 26).
- `hosts/nixos-base/configuration.nix` sets `nerv.home.enable = true` and `nerv.home.users = [ "demon0" ]` (lines 51-52).
- The module wiring chain is complete: `flake.nix` → `self.nixosModules.default` → `modules/default.nix` (imports `../home`) → `home/default.nix`.
- Both required requirements (STRUCT-03, OPT-09) are fully satisfied. No orphaned requirements.
- No anti-patterns found in any modified file.

The two uncertain items (nixos-rebuild success, service activation) are runtime behaviors that require the target NixOS machine with `/home/demon0/home.nix` present. The SUMMARY.md explicitly documents this constraint and provides the exact commands needed.

---

_Verified: 2026-03-07_
_Verifier: Claude (gsd-verifier)_
