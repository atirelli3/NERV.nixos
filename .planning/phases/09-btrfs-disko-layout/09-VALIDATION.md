---
phase: 9
slug: btrfs-disko-layout
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | nix CLI (nix-instantiate --parse, nix eval, nix flake check) |
| **Config file** | flake.nix |
| **Quick run command** | `nix-instantiate --parse modules/system/disko.nix` |
| **Full suite command** | `nix flake check /home/demon/Developments/nerv.nixos` |
| **Estimated runtime** | ~10 seconds (parse) / ~60 seconds (flake check) |

---

## Sampling Rate

- **After every task commit:** Run `nix-instantiate --parse modules/system/disko.nix`
- **After every plan wave:** Run `nix flake check /home/demon/Developments/nerv.nixos`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 9-01-01 | 01 | 1 | DISKO-01 | smoke | `nix-instantiate --parse modules/system/disko.nix` | ✅ | ⬜ pending |
| 9-01-02 | 01 | 1 | DISKO-01 | smoke | `grep -c '"/@"' modules/system/disko.nix` (expect ≥1) | ✅ | ⬜ pending |
| 9-01-03 | 01 | 1 | DISKO-03 | smoke | `grep -c 'space_cache=v2' modules/system/disko.nix` (expect 5) | ✅ | ⬜ pending |
| 9-01-04 | 01 | 1 | DISKO-03 | smoke | `grep -c 'type = "swap"' modules/system/disko.nix` inside isBtrfs — expect 0 | ✅ | ⬜ pending |
| 9-02-01 | 02 | 1 | DISKO-02 | smoke | `nix-instantiate --parse modules/system/disko.nix` | ✅ | ⬜ pending |
| 9-02-02 | 02 | 1 | DISKO-02 | smoke | `grep -c 'lvm_vg' modules/system/disko.nix` (expect ≥1 inside isLvm block) | ✅ | ⬜ pending |
| 9-02-03 | 02 | 2 | DISKO-01,02,03 | smoke | `nix flake check /home/demon/Developments/nerv.nixos` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

None — `modules/system/disko.nix` and `hosts/configuration.nix` already exist. No new test infrastructure required. The existing `nix-instantiate --parse` pattern covers Nix syntax validation.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| BTRFS subvolumes actually created at install time | DISKO-01 | Requires real disk / VM | Boot install with `nerv.disko.layout = "btrfs"`; run `btrfs subvolume list /` and verify @, @root-blank, @home, @nix, @persist, @log present |
| LVM VG + LVs created at install time | DISKO-02 | Requires real disk / VM | Boot install with `nerv.disko.layout = "lvm"`; run `lvdisplay` and verify swap, store, persist LVs present |
| No swap partition in BTRFS branch | DISKO-03 | Requires real disk / VM | Boot install with `nerv.disko.layout = "btrfs"`; run `swapon --show` and verify empty |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
