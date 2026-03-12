---
phase: 14
slug: zram-swap-module
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | NixOS module evaluation via `nix flake check` + manual boot verification |
| **Config file** | none — no test/ directory; consistent with v2.0 phases |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nix flake check && nixos-rebuild dry-build --flake .#host` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check`
- **After every plan wave:** Run `nix flake check && nixos-rebuild dry-build --flake .#host`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | SWAP-01, SWAP-02 | eval | `nix flake check` | ❌ no test file (manual boot) | ⬜ pending |
| 14-01-02 | 01 | 1 | SWAP-03 | eval (assertion) | `nix flake check` | ❌ no test file | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements for eval-time validation.

- [ ] No nixos-test VM infrastructure — SWAP-01 and SWAP-02 require manual boot verification post-deploy
- [ ] SWAP-03 eval assertion validated via `nix flake check` (must fail with assertion message when `layout = "lvm"` and `zram.enable = true`)

*Note: No test/ directory in this project. `nix flake check` handles eval correctness; manual boot handles runtime behavior.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `/dev/zram0` listed in `swapon --show` after boot | SWAP-01 | No VM test infrastructure in repo | Deploy to BTRFS host with `zram.enable = true`; run `swapon --show` |
| `zramctl` shows DISKSIZE = 25% of RAM | SWAP-02 | Runtime kernel state not verifiable at eval time | Deploy with `memoryPercent = 25`; run `zramctl` and compare to `free -m` |
| Priority 100 is set | SWAP-01 | Runtime kernel state | `cat /proc/swaps` — verify priority column shows 100 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
