---
phase: 4
slug: boot-extraction
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-07
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `nixos-rebuild build` (Nix evaluation check) |
| **Config file** | `flake.nix` (root) |
| **Quick run command** | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| **Full suite command** | `nix flake check /home/demon/Developments/test-nerv.nixos` |
| **Estimated runtime** | ~60 seconds (build), ~120 seconds (flake check) |

---

## Sampling Rate

- **After every task commit:** Run `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **After every plan wave:** Run `nix flake check /home/demon/Developments/test-nerv.nixos`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 1 | STRUCT-02 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-01-02 | 01 | 1 | STRUCT-02 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-02-01 | 02 | 1 | IMPL-01 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-02-02 | 02 | 1 | IMPL-02 | assertion/eval | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-02-03 | 02 | 1 | IMPL-03 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-03-01 | 03 | 2 | STRUCT-02 | smoke | `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 4-03-02 | 03 | 2 | STRUCT-02 | smoke | `nix flake check /home/demon/Developments/test-nerv.nixos` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `modules/system/boot.nix` — covers STRUCT-02 (create in boot extraction plan)
- [x] `modules/system/impermanence.nix` — covers IMPL-01, IMPL-02, IMPL-03 (create in impermanence plan)
- [x] `modules/system/secureboot.nix` — covers secureboot migration / OPT-08 (create in secureboot plan)

*All files are created during phase execution — no prior test stubs needed. Existing infrastructure (`nixos-rebuild build`) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| LUKS cross-reference comments present | STRUCT-02 / DOCS-04 | Comment text can't be tested by build | Check that `modules/system/boot.nix`, `hosts/nixos-base/disko-configuration.nix`, and `modules/system/secureboot.nix` each contain a comment referencing the NIXLUKS label cross-dependency |
| IMPL-02 assertion message is human-readable | IMPL-02 | Assertion message quality not machine-verifiable | Trigger assertion by temporarily setting `nerv.impermanence.extraDirs = ["/var/lib/sbctl"]` with `nerv.secureboot.enable = true`, confirm error message is clear |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
