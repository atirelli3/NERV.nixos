---
phase: 12
slug: profile-wiring-and-documentation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shell (grep / nix eval) |
| **Config file** | none — shell checks only |
| **Quick run command** | `grep -q 'nerv.disko.layout = "btrfs"' flake.nix` |
| **Full suite command** | see Per-Task Verification Map |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run the automated command for that task
- **After every plan wave:** Run all automated commands in the wave
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | PROF-01 | grep | `grep -q 'nerv.disko.layout = "btrfs"' flake.nix` | ✅ | ⬜ pending |
| 12-01-02 | 01 | 1 | PROF-01 | grep | `grep -q 'nerv.impermanence.mode    = "btrfs"' flake.nix` | ✅ | ⬜ pending |
| 12-01-03 | 01 | 1 | PROF-02 | grep | `grep -q 'nerv.disko.layout = "lvm"' flake.nix && ! grep -q 'vmProfile' flake.nix` | ✅ | ⬜ pending |
| 12-01-04 | 01 | 1 | PROF-03 | grep | `grep -q 'Options.*nerv.disko.layout' modules/system/disko.nix` | ✅ | ⬜ pending |
| 12-01-05 | 01 | 1 | PROF-04 | grep | `grep -q '@root-blank' README.md && grep -q 'nixos-install' README.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements — no test framework installation needed. All verification is via grep on existing files.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `nix eval .#nixosConfigurations.host.config.nerv.disko.layout` returns `"btrfs"` | PROF-01 | Requires nix installed and flake evaluable | Run `nix eval .#nixosConfigurations.host.config.nerv.disko.layout` in repo root; expect `"btrfs"` |
| `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` returns `"lvm"` | PROF-02 | Requires nix installed and flake evaluable | Run `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` in repo root; expect `"lvm"` |
| README BTRFS install section reads correctly end-to-end | PROF-04 | Prose review | Read README.md Section B; confirm steps are in order: disko → snapshot → nixos-install |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
