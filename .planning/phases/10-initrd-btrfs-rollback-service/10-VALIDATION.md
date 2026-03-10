---
phase: 10
slug: initrd-btrfs-rollback-service
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — NixOS configuration; validation is nix eval + boot-time functional testing |
| **Config file** | none — Wave 0 verifies eval commands work |
| **Quick run command** | `nix flake check /home/demon/Developments/nerv.nixos` |
| **Full suite command** | `nixos-rebuild dry-build --flake /home/demon/Developments/nerv.nixos#nixos-base` |
| **Estimated runtime** | ~30-60 seconds (flake check) |

---

## Sampling Rate

- **After every task commit:** Run `nix flake check /home/demon/Developments/nerv.nixos`
- **After every plan wave:** Run `nixos-rebuild dry-build --flake /home/demon/Developments/nerv.nixos#nixos-base`
- **Before `/gsd:verify-work`:** Full dry-build green + manual boot test (or `rd.systemd.debug_shell` inspection)
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | BOOT-03 | smoke | `nix flake check /home/demon/Developments/nerv.nixos` | ❌ Wave 0 | ⬜ pending |
| 10-01-02 | 01 | 1 | BOOT-03 | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.services.lvm.enable` | ❌ Wave 0 | ⬜ pending |
| 10-02-01 | 02 | 1 | BOOT-01 | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.supportedFilesystems` | ❌ Wave 0 | ⬜ pending |
| 10-02-02 | 02 | 1 | BOOT-01 | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.systemd.storePaths` | ❌ Wave 0 | ⬜ pending |
| 10-02-03 | 02 | 1 | BOOT-02 | smoke | `nix eval .#nixosConfigurations.nixos-base.config.boot.initrd.systemd.services.rollback` | ❌ Wave 0 | ⬜ pending |
| 10-02-04 | 02 | 2 | All | static | `nixos-rebuild dry-build --flake /home/demon/Developments/nerv.nixos#nixos-base` | ❌ Wave 0 | ⬜ pending |
| 10-03-01 | 03 | 2 | All | manual | Boot BTRFS system; verify previous-session files absent from `/` | N/A (manual) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Verify `nix flake check` succeeds from dev machine (check nixos-base configuration attribute is accessible)
- [ ] Confirm `nix eval .#nixosConfigurations.nixos-base.config.*` commands work for targeted attribute inspection

*Both are pre-flight documentation gaps — commands are standard nix eval patterns; confirm correct attribute name for nixosConfiguration.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Root reset on reboot | BOOT-02 | Requires physical/VM boot to verify initrd service runs and `@` is replaced | 1. Boot BTRFS system. 2. Create a test file at `/test-file`. 3. Reboot. 4. Verify `/test-file` is absent — root was reset. |
| LVM absent in BTRFS initrd | BOOT-03 | Full behavior verification requires boot inspection | 1. Boot BTRFS layout system. 2. Check `rd.systemd.debug_shell` or `journalctl -b` for LVM scan absence. 3. System should not hang at boot. |
| Device unit ordering | BOOT-02 | `dev-mapper-cryptroot.device` unit name verification | Run `systemctl list-units \| grep cryptroot` during `rd.systemd.debug_shell` to confirm unit exists. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
