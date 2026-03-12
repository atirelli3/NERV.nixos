---
phase: 10-initrd-btrfs-rollback-service
verified: 2026-03-10T10:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 10: initrd BTRFS Rollback Service Verification Report

**Phase Goal:** Implement layout-conditional initrd configuration in disko.nix (BTRFS rollback service + LVM initrd settings), strip boot.nix to layout-agnostic settings, and update header comments to reflect the new ownership model.
**Verified:** 2026-03-10T10:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth                                                                                                    | Status     | Evidence                                                                    |
|----|----------------------------------------------------------------------------------------------------------|------------|-----------------------------------------------------------------------------|
| 1  | When layout=btrfs, disko.nix declares boot.initrd.supportedFilesystems and storePaths with pkgs.btrfs-progs | VERIFIED | Lines 133-134: both settings present inside mkIf isBtrfs block              |
| 2  | When layout=btrfs, disko.nix declares rollback service after LUKS unlock and before sysroot.mount       | VERIFIED   | Lines 136-153: service with wantedBy=initrd.target, after=dev-mapper-cryptroot.device, before=sysroot.mount |
| 3  | When layout=lvm, disko.nix declares lvm.enable and dm-snapshot; absent when layout=btrfs               | VERIFIED   | Lines 207-208: inside mkIf isLvm only; not present in isBtrfs block         |
| 4  | boot.initrd.luks.devices.cryptroot declared in disko.nix unconditional block and removed from boot.nix  | VERIFIED   | Lines 215-221 of disko.nix; no luks.devices code in boot.nix               |
| 5  | boot.nix retains only 4 settings: kernelPackages, initrd.systemd.enable, systemd-boot.enable, efi.canTouchEfiVariables | VERIFIED | boot.nix lines 15-20: exactly those 4 settings; function args { pkgs, ... } only |
| 6  | disko.nix header Purpose line documents layout-conditional initrd config                                 | VERIFIED   | Lines 3-14: Purpose expanded with per-branch initrd sub-bullets              |
| 7  | disko.nix header Options section lists boot.initrd.* options added in Phase 10                          | VERIFIED   | Lines 17-20: lists supportedFilesystems, storePaths, services.rollback, services.lvm.enable |
| 8  | boot.nix header Purpose reads "layout-agnostic" and cross-references disko.nix                          | VERIFIED   | Lines 3-6: Purpose states layout-agnostic role; explicitly names disko.nix  |
| 9  | boot.nix header no longer mentions LUKS cross-reference                                                  | VERIFIED   | No LUKS section in boot.nix; confirmed by grep                              |

**Score:** 9/9 truths verified

---

### Required Artifacts

| Artifact                     | Expected                                          | Status     | Details                                                                                   |
|------------------------------|---------------------------------------------------|------------|-------------------------------------------------------------------------------------------|
| `modules/system/disko.nix`   | BTRFS initrd block + LVM initrd block + shared LUKS + rollback service | VERIFIED | 224 lines; all four blocks present with correct content                    |
| `modules/system/boot.nix`    | Layout-agnostic bootloader and initrd settings only | VERIFIED | 21 lines; exactly 4 boot.* settings; {pkgs, ...} args only                               |

---

### Key Link Verification

| From                                         | To                                          | Via                                                               | Status   | Details                                                                         |
|----------------------------------------------|---------------------------------------------|-------------------------------------------------------------------|----------|---------------------------------------------------------------------------------|
| disko.nix (mkIf isBtrfs)                     | boot.initrd.systemd.services.rollback       | wantedBy=initrd.target, after=dev-mapper-cryptroot.device, before=sysroot.mount | WIRED | All four ordering attributes confirmed at lines 138-142                        |
| disko.nix (lib.mkMerge third entry)          | boot.initrd.luks.devices."cryptroot"        | Unconditional entry with device=/dev/disk/by-label/NIXLUKS        | WIRED    | Lines 215-221; unconditional placement outside any mkIf guard                  |
| disko.nix (mkIf isLvm)                       | boot.initrd.services.lvm.enable             | Migrated from boot.nix; guarded by isLvm                          | WIRED    | Line 207: present under isLvm guard only                                        |
| boot.nix header                              | modules/system/disko.nix                    | Cross-reference note in Purpose comment                            | WIRED    | Line 6: "lives in modules/system/disko.nix"                                    |

---

### Requirements Coverage

| Requirement | Source Plans | Description                                                                                      | Status    | Evidence                                                                                     |
|-------------|-------------|--------------------------------------------------------------------------------------------------|-----------|----------------------------------------------------------------------------------------------|
| BOOT-01     | 10-01, 10-02 | When layout=btrfs, initrd includes btrfs-progs via supportedFilesystems and storePaths          | SATISFIED | disko.nix lines 133-134 inside mkIf isBtrfs block                                           |
| BOOT-02     | 10-01, 10-02 | When layout=btrfs, rollback service runs after dev-mapper-cryptroot.device, before sysroot.mount | SATISFIED | disko.nix lines 136-153; all ordering attributes and script using full store paths confirmed |
| BOOT-03     | 10-01, 10-02 | LVM initrd services active only when layout=lvm; disabled for BTRFS                             | SATISFIED | disko.nix lines 207-208 under mkIf isLvm; absent from isBtrfs block and boot.nix            |

**Note on BOOT-03 and preLVM:** REQUIREMENTS.md describes `preLVM = true` as part of the expected LVM initrd settings. The implementation deliberately omits it because `preLVM` is silently ignored by systemd stage 1 (when `boot.initrd.systemd.enable = true`). This omission is documented in Plan 01 and the code comment at line 219 of disko.nix. The functional requirement — LVM activation and dm-snapshot guarded to layout=lvm only — is fully satisfied.

**Orphaned requirements check:** No requirements mapped to Phase 10 in REQUIREMENTS.md beyond BOOT-01, BOOT-02, BOOT-03. No orphaned requirements.

---

### Anti-Patterns Found

| File                       | Line | Pattern                                                       | Severity | Impact                                                                              |
|----------------------------|------|---------------------------------------------------------------|----------|-------------------------------------------------------------------------------------|
| `modules/system/disko.nix` | 50   | Stale inline comment: "must stay in sync with boot.nix and secureboot.nix" | Info | NIXLUKS label is a disko.nix format argument; boot.nix no longer declares LUKS. Comment should read "secureboot.nix" only, matching the header on line 21. Does not affect runtime correctness. |
| `modules/system/default.nix` | 14 | Stale module description: "initrd + LUKS + bootloader" for boot.nix import | Info | Carries the pre-Phase-10 description. Does not affect correctness or goal achievement. |

No blockers. No stubs. No missing implementations.

---

### Human Verification Required

The following cannot be verified statically on a Darwin dev machine:

**1. nix flake check evaluation**

- **Test:** Run `nix flake check` on the NixOS host where evaluation is available
- **Expected:** Exits 0; all nixosConfigurations parse without error; no attribute type errors from the new boot.initrd.systemd.services.rollback attrset
- **Why human:** Nix evaluation unavailable on Darwin dev machine; structural correctness was confirmed by code review only (SUMMARY acknowledges this)

**2. Rollback service runtime behavior**

- **Test:** Boot a BTRFS-layout host; observe initrd log output for the rollback service; verify `@` subvolume is recreated from `@root-blank` on every reboot
- **Expected:** Service starts after LUKS unlock, deletes old `@`, snapshots `@root-blank` to `@`, unmounts `/btrfs_tmp`, then sysroot.mount proceeds
- **Why human:** Runtime systemd service behavior in initrd cannot be verified statically

**3. LVM initrd isolation**

- **Test:** Boot an LVM-layout host; confirm LVM PV scan activates cleanly with no btrfs-related errors
- **Expected:** No rollback service in initrd; LVM activates; no errors
- **Why human:** Runtime behavior only

---

### Gaps Summary

No gaps. All nine observable truths verified. All artifacts are substantive and wired. All three requirement IDs fully satisfied. Git history confirms all four commits (c2cbf10, 9a1955a, 2570f46, bf4b107) exist and correspond to the claimed work.

Two stale inline comments are noted as informational findings — they do not block the phase goal and are candidates for cleanup in a future documentation pass.

---

## Commit Verification

All commits from SUMMARY files confirmed present in git history:

| Commit  | Message                                                                  | Plan |
|---------|--------------------------------------------------------------------------|------|
| c2cbf10 | feat(10-01): extend disko.nix with BTRFS rollback service, LVM initrd, and shared LUKS unlock | 01   |
| 9a1955a | feat(10-01): strip boot.nix to layout-agnostic settings only             | 01   |
| 2570f46 | docs(10-02): update disko.nix header to reflect Phase 10 additions       | 02   |
| bf4b107 | docs(10-02): update boot.nix header to layout-agnostic role              | 02   |

---

_Verified: 2026-03-10T10:00:00Z_
_Verifier: Claude (gsd-verifier)_
