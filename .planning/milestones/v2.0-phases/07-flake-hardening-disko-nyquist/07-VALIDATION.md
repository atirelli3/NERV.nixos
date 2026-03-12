---
phase: 7
slug: flake-hardening-disko-nyquist
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-08
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | nix CLI (nix flake show, nix-instantiate --parse, nixos-rebuild build) |
| **Config file** | flake.nix |
| **Quick run command** | `nix flake show /home/demon/Developments/test-nerv.nixos` |
| **Full suite command** | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| **Estimated runtime** | ~30 seconds (quick), ~120 seconds (full) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake show /home/demon/Developments/test-nerv.nixos`
- **After every plan wave:** Run `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 7-01-01 | 01 | 1 | Tech debt B | smoke | `nix flake show /home/demon/Developments/test-nerv.nixos` | ✅ | ✅ green |
| 7-01-02 | 01 | 1 | Tech debt C | smoke | `grep -E 'nerv\.(secureboot\|impermanence)\.enable' /home/demon/Developments/test-nerv.nixos/hosts/nixos-base/configuration.nix` | ✅ | ✅ green |
| 7-01-03 | 01 | 1 | Tech debt B+C | integration | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` | ✅ | ✅ green |
| 7-02-01 | 02 | 1 | Tech debt D | smoke | `nix flake show /home/demon/Developments/test-nerv.nixos` | ✅ | ✅ green |
| 7-02-02 | 02 | 1 | Tech debt D | integration | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` | ✅ | ✅ green |
| 7-03-01 | 03 | 2 | Tech debt E (phases 1-3) | smoke | `grep 'nyquist_compliant: true' /home/demon/Developments/test-nerv.nixos/.planning/phases/0{1,2,3}*/*.md \| wc -l` | ✅ | ✅ green |
| 7-04-01 | 04 | 2 | Tech debt E (phases 4-6) | smoke | `grep 'nyquist_compliant: true' /home/demon/Developments/test-nerv.nixos/.planning/phases/0{4,5,6}*/*.md \| wc -l` | ✅ | ✅ green |
| 7-04-02 | 04 | 2 | Tech debt E (all) | smoke | `grep 'nyquist_compliant: true' /home/demon/Developments/test-nerv.nixos/.planning/phases/*/*.md \| wc -l` (expect 6) | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test files need to be created.

`nix flake show`, `nixos-rebuild build`, `nix-instantiate --parse`, and `grep` are all available in the native Nix toolchain.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| disko module does not conflict with boot.nix LUKS config | Tech debt D | Build-time LUKS conflict can only be confirmed by inspecting generated NixOS config | After `nixos-rebuild build`, run `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.luks.devices` and verify no duplicate `cryptroot` entry |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-03-08
