---
phase: 2
slug: services-reorganization
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-06
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | NixOS evaluator (no traditional test framework — Nix itself is the oracle) |
| **Config file** | `flake.nix` |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nixos-rebuild build --flake .#nixos-base` |
| **Estimated runtime** | ~30 seconds (flake check) / ~120 seconds (full build) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check`
- **After every plan wave:** Run `nixos-rebuild build --flake .#nixos-base`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 2-openssh-01 | openssh | 1 | OPT-05 | smoke | `nix flake check` — evaluates AllowUsers omission when empty list | ✅ | ✅ green |
| 2-openssh-02 | openssh | 1 | OPT-06 | smoke | `nix flake check` — evaluates PasswordAuthentication = false | ✅ | ✅ green |
| 2-openssh-03 | openssh | 1 | OPT-07 | smoke | `nix flake check` — evaluates port propagation to fail2ban jail | ✅ | ✅ green |
| 2-audio-01 | audio | 1 | OPT-08 | smoke | `nix flake check` + `nixos-rebuild build --flake .#nixos-base` | ✅ | ✅ green |
| 2-bluetooth-01 | bluetooth | 1 | OPT-08 | smoke | `nix flake check` | ✅ | ✅ green |
| 2-printing-01 | printing | 1 | OPT-08 | smoke | `nix flake check` | ✅ | ✅ green |
| 2-zsh-01 | zsh | 1 | OPT-08 | smoke | `nix flake check` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Verify `nix` is available: `nix --version`
- [x] Verify `nix flake check` passes on current state before any changes (baseline)

*No traditional test files to create — NixOS modules are validated by the Nix evaluator itself. The "test infrastructure" is correct module authoring + build verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSH login works with configured `allowUsers` | OPT-05 | Requires live system boot | Boot nixos-base VM, attempt SSH as listed user |
| Audio plays after `nerv.audio.enable = true` | OPT-08 | Requires live system + hardware | Boot with audio enabled, run `paplay /usr/share/sounds/alsa/Front_Center.wav` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
