---
phase: 8
slug: legacy-module-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-08
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | nix eval / nix flake check (no test framework — NixOS config validation) |
| **Config file** | flake.nix |
| **Quick run command** | `nix flake check --no-build 2>&1 \| tail -5` |
| **Full suite command** | `nix flake check 2>&1` |
| **Estimated runtime** | ~30–120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check --no-build 2>&1 | tail -5`
- **After every plan wave:** Run `nix flake check 2>&1`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 8-01-01 | 01 | 1 | dead-modules | shell | `ls modules/*.nix 2>/dev/null \| wc -l` (expect 0) | ⬜ pending |
| 8-01-02 | 01 | 1 | dead-modules | shell | `nix flake check --no-build` | ⬜ pending |
| 8-02-01 | 02 | 1 | IMPL-04 | manual | nix eval `.#nixosConfigurations.server.config.fileSystems` | ⬜ pending |
| 8-02-02 | 02 | 1 | IMPL-04 | shell | `nix flake check --no-build` | ⬜ pending |
| 8-03-01 | 03 | 2 | IMPL-05 | shell | `nix flake check --no-build` | ⬜ pending |
| 8-03-02 | 03 | 2 | IMPL-05 | manual | inspect flake.nix for hostProfile/serverProfile/vmProfile | ⬜ pending |
| 8-04-01 | 04 | 3 | IMPL-06 | shell | `git -C <NERV.nixos-path> log --oneline -3` | ⬜ pending |
| 8-04-02 | 04 | 3 | reset | manual | `git log --oneline -1` (expect cab4126e) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework installation needed — validation uses `nix flake check` (built-in) and shell assertions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full impermanence activates correctly on server | IMPL-04 | Requires actual boot — cannot evaluate at build time | On a VM: boot with serverProfile config, verify `/` resets on reboot, `/persist` survives |
| NERV.nixos repo accessible via git | IMPL-06 | Requires GitHub network + SSH key | `git ls-remote git@github.com:atirelli3/NERV.nixos.git` |
| test-nerv.nixos reset to cab4126e | reset | Destructive git operation — user must confirm | `git log --oneline -1` on test-nerv.nixos after reset |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
