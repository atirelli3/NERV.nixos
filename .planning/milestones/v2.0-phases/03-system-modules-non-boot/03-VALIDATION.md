---
phase: 3
slug: system-modules-non-boot
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-07
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — NixOS evaluator is the primary validator |
| **Config file** | none |
| **Quick run command** | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| **Full suite command** | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| **Estimated runtime** | ~30–120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **After every plan wave:** Run `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | OPT-01 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-01-02 | 01 | 1 | OPT-01 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-02-01 | 02 | 1 | OPT-02 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-03-01 | 03 | 1 | OPT-03 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-03-02 | 03 | 1 | OPT-03 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-04-01 | 04 | 1 | OPT-04 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 3-05-01 | 05 | 2 | OPT-01–04 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*None — no test framework to install. The NixOS evaluator is the test infrastructure. Build command must pass after each task.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `nerv.primaryUser` group membership applied at runtime | OPT-02 | Requires activated system; `id` command needed | After `nixos-rebuild switch`, run `id demon0` and confirm `wheel` and `networkmanager` in groups |
| `nerv.hardware.cpu = "amd"` kernel params present in boot | OPT-03 | Requires activated system; kernel cmdline check | After switch, run `cat /proc/cmdline` and confirm `amd_iommu=on iommu=pt` present |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
