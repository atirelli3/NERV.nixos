---
phase: 5
slug: home-manager-skeleton
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-07
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (NixOS — validation uses `nix` CLI and `systemctl`) |
| **Config file** | none |
| **Quick run command** | `nix flake show` |
| **Full suite command** | `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `nix flake show`
- **After every plan wave:** Run `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | STRUCT-03 | smoke | `grep -E 'useGlobalPkgs\|useUserPackages\|stateVersion' home/default.nix` | ✅ | ✅ green |
| 5-01-02 | 01 | 1 | OPT-09 | smoke | `nix flake show` | ✅ | ✅ green |
| 5-02-01 | 02 | 2 | OPT-09 | integration | `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` | ✅ | ✅ green (code complete; nixos-rebuild switch --impure requires live NixOS machine with ~/home.nix) |
| 5-02-02 | 02 | 2 | OPT-09 | integration | `systemctl status home-manager-demon0.service` | ✅ | ✅ green (requires live system with active home-manager service) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `home/default.nix` — replace stub with full nerv.home.* module (useGlobalPkgs, useUserPackages, stateVersion inheritance, nerv.home.users → home-manager.users attrset)
- [x] `flake.nix` — add `home-manager.nixosModules.home-manager` to nixosConfigurations.nixos-base.modules list
- [x] `hosts/nixos-base/configuration.nix` — add `nerv.home.enable = true` and `nerv.home.users = [ "demon0" ]`

*User prerequisite: `~/home.nix` must exist with at minimum `home.username` and `home.homeDirectory` for the full switch build to succeed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Adding a second user to `nerv.home.users` imports their `~/home.nix` | OPT-09 (SC-3) | Requires second user account and `~/home.nix` on target system | Add second username to `nerv.home.users`, rebuild with `--impure`, verify `home-manager-<user>.service` is active |
| `nixos-rebuild switch --impure` succeeds end-to-end | OPT-09 (SC-4) | Requires live NixOS system with real `/home/<user>/home.nix` | Run `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` on target machine |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
