---
phase: 6
slug: documentation-sweep
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-07
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | nix-instantiate --parse (built-in Nix parser) |
| **Config file** | none — no test framework needed |
| **Quick run command** | `nix-instantiate --parse <file>` |
| **Full suite command** | `find modules/ hosts/nixos-base/ -name '*.nix' -exec nix-instantiate --parse {} \;` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix-instantiate --parse <edited-file>`
- **After every plan wave:** Run full parse sweep of all modified files
- **Before `/gsd:verify-work`:** Full suite must be green + header audit passes
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 1 | DOCS-01 | parse | `nix-instantiate --parse modules/services/openssh.nix` | ✅ | ✅ green |
| 6-01-02 | 01 | 1 | DOCS-01, DOCS-02 | parse | `nix-instantiate --parse modules/services/pipewire.nix` | ✅ | ✅ green |
| 6-01-03 | 01 | 1 | DOCS-01, DOCS-02 | parse | `nix-instantiate --parse modules/services/bluetooth.nix` | ✅ | ✅ green |
| 6-01-04 | 01 | 1 | DOCS-01, DOCS-02 | parse | `nix-instantiate --parse modules/services/printing.nix` | ✅ | ✅ green |
| 6-01-05 | 01 | 1 | DOCS-01, DOCS-02 | parse | `nix-instantiate --parse modules/services/zsh.nix` | ✅ | ✅ green |
| 6-02-01 | 02 | 1 | DOCS-01 | parse | `nix-instantiate --parse modules/services/default.nix` | ✅ | ✅ green |
| 6-02-02 | 02 | 1 | DOCS-01 | parse | `nix-instantiate --parse modules/system/default.nix` | ✅ | ✅ green |
| 6-02-03 | 02 | 1 | DOCS-01 | parse | `nix-instantiate --parse home/default.nix` | ✅ | ✅ green |
| 6-03-01 | 03 | 1 | DOCS-01, DOCS-02 | parse | `nix-instantiate --parse hosts/nixos-base/configuration.nix` | ✅ | ✅ green |
| 6-03-02 | 03 | 1 | DOCS-01, DOCS-03, DOCS-04 | parse | `nix-instantiate --parse hosts/nixos-base/disko-configuration.nix` | ✅ | ✅ green |
| 6-03-03 | 03 | 1 | DOCS-01 | parse | `nix-instantiate --parse hosts/nixos-base/hardware-configuration.nix` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test stubs needed — `nix-instantiate --parse` is available in all Nix environments.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Section-header content quality | DOCS-01 | Automated parse only checks syntax, not semantic completeness of headers | Read each file's header block; verify Purpose, Defaults, and Override sections are present and accurate |
| Inline comment coverage | DOCS-02 | "Non-obvious" is subjective | Skim each module for config lines without comments; verify security-relevant lines (ports, allowed users, etc.) are explained |
| Disko warning visibility | DOCS-03 | Must be "prominent" — reader judgment required | Open disko-configuration.nix; verify warning appears before any Nix expressions and lists /dev/DISK and SIZE_RAM * 2 |
| LUKS cross-reference accuracy | DOCS-04 | Label string correctness requires manual verification | Check the label string in both disko-configuration.nix and boot.nix match exactly; verify each cross-references the other file by name |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
