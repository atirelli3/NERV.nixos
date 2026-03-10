---
phase: 11
slug: impermanence-btrfs-mode
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — NixOS eval via `nix flake check` |
| **Config file** | none — no test infra (consistent with Phases 9 and 10) |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nix flake check` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check`
- **After every plan wave:** Run `nix flake check`
- **Before `/gsd:verify-work`:** Full suite must be green + manual `nix eval` spot-checks for PERSIST-01 and PERSIST-02
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | PERSIST-01 | eval/smoke | `nix flake check` | ❌ W0 (manual eval) | ⬜ pending |
| 11-01-02 | 01 | 1 | PERSIST-02 | eval/smoke | `nix flake check` | ❌ W0 (manual eval) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- No new test files needed — validation is via `nix flake check` (eval) and manual `nix eval` / `nixos-option` checks, consistent with all previous phases.

*Existing infrastructure (nix flake check) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `nerv.impermanence.mode = "btrfs"` activates `environment.persistence."/persist"` with correct dirs/files; `/var/log` absent | PERSIST-01 | No automated NixOS eval test infra; requires `nix eval` on built config | Run: `nix eval .#nixosConfigurations.host.config.environment.persistence` — verify expected paths present, `/var/log` absent |
| `fileSystems."/persist".neededForBoot` evaluates to `true` in btrfs mode | PERSIST-02 | Requires live system or `nix eval` inspection | Run: `nix eval .#nixosConfigurations.host.config.fileSystems."/persist".neededForBoot` — must evaluate to `true` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
