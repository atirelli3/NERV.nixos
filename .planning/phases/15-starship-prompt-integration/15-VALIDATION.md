---
phase: 15
slug: starship-prompt-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-12
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual shell inspection (NixOS module — no unit test harness applies) |
| **Config file** | none — no automated test files needed |
| **Quick run command** | `nix flake check` |
| **Full suite command** | `nix flake check && nix build .#nixosConfigurations.host.config.system.build.toplevel` |
| **Estimated runtime** | ~60–120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check`
- **After every plan wave:** Run `nix flake check && nix build .#nixosConfigurations.host.config.system.build.toplevel`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | PRMT-01 | build | `nix flake check` | ✅ | ⬜ pending |
| 15-01-02 | 01 | 1 | PRMT-01 | build | `nix flake check` | ✅ | ⬜ pending |
| 15-01-03 | 01 | 1 | PRMT-02 | build | `nix flake check` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

NixOS flake check validates module composition. Manual verification covers visual prompt appearance and ZLE binding behavior, which cannot be automated without a running shell session.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Two-line starship prompt visible on shell open | PRMT-01 | Requires live shell session | Open new terminal, verify line 1 shows dim cyan username, line 2 shows `$` |
| `$` turns red after non-zero exit code | PRMT-01 | Requires running commands | Run `false`, verify prompt character is red; run `true`, verify it is white |
| Arrow-key history search works after starship loads | PRMT-01 | ZLE binding behavior | Type partial command, press up-arrow, verify history-substring-search still works |
| `echo $STARSHIP_CONFIG` resolves to Nix store path | PRMT-02 | Requires live shell | Run `echo $STARSHIP_CONFIG`, verify path contains `/nix/store/` |
| Prompt survives root subvolume rollback | PRMT-02 | Requires impermanence setup | Verify `STARSHIP_CONFIG` is store path (not `~/.config/starship.toml`) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
