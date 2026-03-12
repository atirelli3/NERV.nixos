---
phase: 13
slug: audit-gap-closure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — NixOS flake project; validation is `nix eval` + grep |
| **Config file** | N/A |
| **Quick run command** | `grep -n "nixosConfigurations.server" flake.nix` |
| **Full suite command** | `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` (if nix available) |
| **Estimated runtime** | ~5 seconds (grep); ~30 seconds (nix eval) |

---

## Sampling Rate

- **After every task commit:** Run grep-based spot check per task (see map below)
- **After every plan wave:** Run `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` if nix available; otherwise manual inspection
- **Before `/gsd:verify-work`:** All grep checks green, README step numbers sequential 1–14
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | PROF-02 | grep | `grep -n "serverProfile\|server =" flake.nix` | ❌ W0 | ⬜ pending |
| 13-01-02 | 01 | 1 | DISKO-02 | grep | `grep -n "nixosConfigurations.server" flake.nix` | ❌ W0 | ⬜ pending |
| 13-01-03 | 01 | 1 | DISKO-02 | smoke | `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` | ❌ W0 | ⬜ pending |
| 13-02-01 | 02 | 1 | PROF-04 | grep | `grep "@root-blank" README.md` | ❌ W0 | ⬜ pending |
| 13-02-02 | 02 | 1 | PROF-04 | manual | Verify step numbers in README Section A are sequential 1–14 | ❌ W0 | ⬜ pending |
| 13-03-01 | 03 | 1 | BOOT-02 | grep | `grep "# Profiles :" modules/system/disko.nix modules/system/boot.nix modules/system/impermanence.nix` | ❌ W0 | ⬜ pending |
| 13-04-01 | 04 | 1 | PROF-03 | grep | `grep -n "declarative disk layout" modules/system/default.nix` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- No test framework to install — this is a NixOS flake project
- Validation via `nix` CLI or grep/manual inspection

*Existing infrastructure (nix eval + grep) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README Section A step numbers sequential 1–14 | PROF-04 | No test framework; visual count | Read README.md Section A, verify steps renumbered 1–14 after new snapshot step inserted |
| `nixosConfigurations.server` mirrors `host` structure | DISKO-02 | Structural review | Compare `nixosConfigurations.host` and `nixosConfigurations.server` blocks in flake.nix for structural parity |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
