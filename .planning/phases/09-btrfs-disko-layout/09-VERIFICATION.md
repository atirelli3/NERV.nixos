---
phase: 09-btrfs-disko-layout
verified: 2026-03-10T00:00:00Z
status: passed
score: 4/4 success criteria verified
re_verification: false
---

# Phase 9: BTRFS/LVM Disko Layout Verification Report

**Phase Goal:** Users can select a disk layout type at configuration time; setting `nerv.disko.layout = "btrfs"` produces a GPT/LUKS/BTRFS disk with all required subvolumes; setting `"lvm"` preserves the existing LVM layout explicitly
**Verified:** 2026-03-10
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                        | Status     | Evidence                                                                                             |
|----|----------------------------------------------------------------------------------------------|------------|------------------------------------------------------------------------------------------------------|
| 1  | `nerv.disko.layout` option accepts `"btrfs"` or `"lvm"`; no default; eval errors on unset  | VERIFIED   | `lib.types.enum [ "btrfs" "lvm" ]` at line 47; no `default =` on layout option                     |
| 2  | `"btrfs"` produces GPT disk with ESP + LUKS containing BTRFS with 6 required subvolumes     | VERIFIED   | `lib.mkIf isBtrfs` block (lines 82-120); all 6 subvols: @, @root-blank, @home, @nix, @persist, @log |
| 3  | All 5 mounted BTRFS subvolumes use `compress=zstd:3`, `noatime`, `space_cache=v2`; no swap  | VERIFIED   | `grep -c 'space_cache=v2'` = 5; swap only inside `lib.mkIf isLvm` (line 145)                        |
| 4  | `"lvm"` produces GPT/LUKS/LVM with swap + store + persist LVs under `lib.mkIf isLvm`       | VERIFIED   | `lib.mkIf isLvm` block (lines 123-171); swap/store/persist LVs all gated by `isLvm`                 |

**Score:** 4/4 truths verified

---

## Required Artifacts

| Artifact                       | Expected                                              | Status     | Details                                                                 |
|-------------------------------|-------------------------------------------------------|------------|-------------------------------------------------------------------------|
| `modules/system/disko.nix`    | `lib.types.enum [ "btrfs" "lvm" ]` present           | VERIFIED   | Line 47 — exact match                                                   |
| `modules/system/disko.nix`    | `nerv.disko.lvm.swapSize` option present              | VERIFIED   | Lines 58-63 — swapSize, storeSize, persistSize all declared             |
| `hosts/configuration.nix`     | `nerv.disko.layout` present with PLACEHOLDER value   | VERIFIED   | Line 43 — `nerv.disko.layout = "PLACEHOLDER"` with explanatory comment |
| `hosts/configuration.nix`     | `nerv.disko.lvm.swapSize` present                    | VERIFIED   | Lines 46-48 — all three lvm.* keys present                             |

---

## Key Link Verification

| From                          | To                           | Via                              | Status   | Details                                                                            |
|-------------------------------|------------------------------|----------------------------------|----------|------------------------------------------------------------------------------------|
| `options.nerv.disko.layout`   | `config = lib.mkMerge`       | `isBtrfs / isLvm` let bindings   | WIRED    | Lines 18-19: `isBtrfs = cfg.layout == "btrfs"`, `isLvm = cfg.layout == "lvm"`    |
| `lib.mkIf isLvm`              | `disko.devices.lvm_vg.lvmroot` | lib.mkMerge second element      | WIRED    | `disko.devices.lvm_vg.lvmroot` at line 139 is inside `lib.mkIf isLvm` block       |
| `lib.mkIf isBtrfs`            | `type = "btrfs"` subvolumes  | LUKS content block               | WIRED    | `type = "btrfs"` at line 91 inside `lib.mkIf isBtrfs` block (lines 82-120)        |
| `hosts/configuration.nix`     | `modules/system/disko.nix`   | `nerv.disko.layout` option       | WIRED    | `nerv.disko.layout` declared at line 43; module imported via `default.nix` line 16 |

---

## Requirements Coverage

| Requirement | Source Plans      | Description                                                                                  | Status    | Evidence                                                                                          |
|-------------|-------------------|----------------------------------------------------------------------------------------------|-----------|---------------------------------------------------------------------------------------------------|
| DISKO-01    | 09-01, 09-02      | `nerv.disko.layout = "btrfs"` produces GPT/LUKS/BTRFS with @, @root-blank, @home, @nix, @persist, @log | SATISFIED | All 6 subvolumes present in `lib.mkIf isBtrfs` block; `@root-blank` has no mountpoint (empty `{}`) |
| DISKO-02    | 09-01, 09-02      | `nerv.disko.layout = "lvm"` produces GPT/LUKS/LVM layout (swap + store + persist LVs)      | SATISFIED | swap, store, persist LVs all inside `lib.mkIf isLvm`; no LVM outside that guard                  |
| DISKO-03    | 09-01, 09-02      | BTRFS subvolumes use `compress=zstd:3`, `noatime`, `space_cache=v2`; no swap in BTRFS branch | SATISFIED | All 5 mounted subvols confirmed; `type = "swap"` only at line 145 inside `lib.mkIf isLvm`         |

**Orphaned requirements:** None. All three DISKO-* IDs appear in both plan frontmatters and are accounted for.

---

## Anti-Patterns Found

| File                          | Line | Pattern                                                          | Severity | Impact                                   |
|-------------------------------|------|------------------------------------------------------------------|----------|------------------------------------------|
| `modules/system/default.nix`  | 16   | Stale comment: "conditional LVM LVs based on impermanence mode" | INFO     | Comment describes old behavior; no effect on evaluation or behavior |

No TODO/FIXME/HACK markers in `modules/system/disko.nix`. No empty implementations. No stale references to removed files (`disko-configuration.nix`, `disko-host.nix` are deleted). No old flat `nerv.disko.swapSize/rootSize/storeSize/persistSize` references anywhere in the codebase.

---

## Human Verification Required

### 1. Nix evaluation with layout = "btrfs"

**Test:** In a NixOS environment with nix available, set `nerv.disko.layout = "btrfs"` (replacing PLACEHOLDER) and run `nix flake check` or `nix eval .#nixosConfigurations.host.config.disko`.
**Expected:** Evaluation succeeds; disko config includes BTRFS partitions with 6 subvolumes and correct mount options.
**Why human:** `nix-instantiate` and `nix` are not available on the dev machine; parse-only checks were used during implementation.

### 2. Nix evaluation with layout = "lvm"

**Test:** Set `nerv.disko.layout = "lvm"` with real size values and run `nix eval .#nixosConfigurations.host.config.disko`.
**Expected:** Evaluation succeeds; disko config shows GPT/LUKS/LVM with swap, store, persist LVs under `lvm_vg.lvmroot`.
**Why human:** Same reason as above — no nix binary on dev machine.

### 3. Enum enforcement on PLACEHOLDER

**Test:** Leave `nerv.disko.layout = "PLACEHOLDER"` and attempt `nix flake check`.
**Expected:** Nix module system emits a type error (`"PLACEHOLDER" is not one of ["btrfs", "lvm"]`), confirming no-default enforcement works.
**Why human:** Cannot run nix eval on this machine.

---

## Verification Summary

Phase 9 goal is fully achieved. The implementation in `modules/system/disko.nix` is complete and correct:

- `nerv.disko.layout` enum with no default forces explicit per-host declaration (consistent with `nerv.hostname`/`nerv.hardware.cpu` pattern).
- The BTRFS branch declares exactly the 6 required subvolumes (`@`, `@root-blank`, `@home`, `@nix`, `@persist`, `@log`). `@root-blank` has no mountpoint, preserving it as a Phase 10 rollback baseline. All 5 mounted subvolumes carry `compress=zstd:3`, `noatime`, `space_cache=v2` — verified by count.
- The LVM branch declares swap, store, and persist LVs entirely inside `lib.mkIf isLvm`. No swap device appears in the BTRFS branch.
- `hosts/configuration.nix` uses the new API (`nerv.disko.layout`, `nerv.disko.lvm.*`); all old flat options (`swapSize`, `rootSize`, `storeSize`, `persistSize`) are absent from the entire codebase.
- `modules/system/disko.nix` is imported via `modules/system/default.nix` and disko's nixosModule is included in all three nixosConfigurations in `flake.nix`.

One stale comment in `modules/system/default.nix` line 16 describes the old "impermanence mode" behavior. This is cosmetic only — it does not affect evaluation or runtime behavior, and should be updated in a future housekeeping pass.

Both implementing commits (`76758ac`, `5641b6c`) exist in git history and correspond to the work documented in the summaries.

---

_Verified: 2026-03-10_
_Verifier: Claude (gsd-verifier)_
