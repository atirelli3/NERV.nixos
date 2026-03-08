---
phase: 1
slug: flake-foundation
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-06
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (NixOS — validation uses `nix` CLI commands, not a test runner) |
| **Config file** | none |
| **Quick run command** | `nix flake show` |
| **Full suite command** | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| **Estimated runtime** | ~30–120 seconds (build time varies) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake show`
- **After every plan wave:** Run `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | STRUCT-01 | smoke | `ls modules/system/default.nix modules/services/default.nix home/default.nix` | ✅ | ✅ green |
| 1-01-02 | 01 | 1 | STRUCT-04 | integration | `nix flake show 2>&1 \| grep -E 'nixosModules\.(default\|system\|services\|home)'` | ✅ | ✅ green |
| 1-01-03 | 01 | 1 | STRUCT-05 | smoke | `grep -E 'home-manager\|impermanence' flake.nix && grep 'nixpkgs.follows' flake.nix` | ✅ | ✅ green — STRUCT-05 satisfied via home-manager; impermanence input removed in Phase 7 Plan 01 |
| 1-01-04 | 01 | 1 | STRUCT-04 | integration | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `flake.nix` — root library flake (does not exist yet)
- [x] `modules/default.nix` — aggregator (does not exist yet)
- [x] `modules/system/default.nix` — stub (does not exist yet)
- [x] `modules/services/default.nix` — stub (does not exist yet)
- [x] `home/default.nix` — stub (does not exist yet)
- [x] `base/flake.nix` — needs update (exists, needs rewrite)

All gaps are the deliverables of this phase. No test framework installation needed — validation uses `nix` CLI which is the project's native toolchain.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `nix flake show` output lists all 4 nixosModules entries | STRUCT-04 | Requires visual inspection of CLI output format | Run `nix flake show` from repo root; confirm `nixosModules.default`, `nixosModules.system`, `nixosModules.services`, `nixosModules.home` all appear |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
