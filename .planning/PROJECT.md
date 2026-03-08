# nerv.nixos

## What This Is

A general-purpose, opinionated NixOS flake providing hardened system defaults as composable modules. End users extend it by writing their own minimal host flake that overrides only what's specific to their machine — CPU type, SSH policy, hostname, keyboard layout, DE/WM. The project aims to be reusable across pc/desktop, server, and VM targets.

## Core Value

A user should be able to declare only their machine-specific parameters and get a secure, well-documented NixOS system out of the box.

## Requirements

### Validated

- ✓ LUKS-on-LVM full disk encryption with Disko — existing
- ✓ Hardened kernel with security modules (secureboot, kernel.nix, security.nix) — existing
- ✓ SSH hardening with fail2ban, endlessh, and port-knocking patterns — existing
- ✓ PipeWire audio setup — existing
- ✓ Bluetooth with OBEX file transfer support — existing
- ✓ Printing support — existing
- ✓ Nix daemon hardening (nix.nix) — existing
- ✓ ZSH as default shell — existing
- ✓ Base system flake with working hardware-configuration layout — existing

### Active

- [ ] Reorganize repo into nested modules/system/ + modules/services/ structure
- [ ] Add home/ skeleton for Home Manager integration
- [ ] Add impermanence module for tmpfs on ~/Downloads, /tmp, ~/Desktop
- [ ] Expose NixOS module options API for user-overridable parameters (openssh, hardware, locale)
- [ ] Add section-header + inline documentation to all modules and base files
- [ ] Extract boot/disk config from configuration.nix into modules/system/boot.nix
- [ ] Separate hardware CPU/GPU config into modules/system/hardware.nix with typed options

### Out of Scope

- Full home impermanence ($HOME on tmpfs) — too opinionated for a general base; users can add this themselves
- DE/WM/DM configuration — belongs in the user's host flake, not the base
- Home Manager dotfiles — skeleton only; actual dotfiles are user responsibility
- Multi-host examples/templates — out of scope for v1, added after structure is stable

## Context

Existing codebase has working flakes in base/ (configuration.nix, disko-configuration.nix, flake.nix) and modules/ (10 .nix files). The reorganization targets these two directories.

**Deployed layout (single-repo):** Everything lives under `/etc/nerv` — library modules in `modules/`, host machine configs in `hosts/<hostname>/`. `/etc/nixos` is not used. Build command: `nixos-rebuild switch --flake /etc/nerv#<hostname>`. The root `flake.nix` exports both `nixosModules` (library) and `nixosConfigurations` (hosts) using `self` references.

**Home Manager split:** `home/default.nix` in this repo is the NixOS wiring module only (enables HM, sets `useGlobalPkgs`, `useUserPackages`, `stateVersion`). User dotfiles (packages, programs, dotfiles) live in a separate user-owned repo under `$HOME/dotfiles/` and are not part of nerv.

Key reference implementations used during initial development:
- nix-mineral hardening baseline
- xeiaso paranoid NixOS patterns
- NixOS wiki patterns for SSH, PipeWire, Bluetooth, fail2ban

## Constraints

- **Tech stack**: Pure NixOS flakes, no non-Nix tooling
- **Compatibility**: Must remain valid for NixOS 25.11 (current stateVersion)
- **Override mechanism**: NixOS module options where practical, lib.mkForce as fallback for edge cases
- **Scope**: System-level config only in modules/; Home Manager in home/ skeleton form

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nested modules/system/ + modules/services/ | Mirrors /etc/nerv vision, clear separation of kernel/hardware vs daemon concerns | — Pending |
| NixOS module options as primary override API | Idiomatic, type-checked, self-documenting; lib.mkForce as escape hatch | — Pending |
| Broader tmpfs impermanence (Downloads, /tmp, Desktop) | Minimal privacy/cleanliness wins without full home impermanence complexity | — Pending |
| Include Home Manager skeleton in v1 | Users need a place to hook HM; skeleton costs little and avoids structural rework later | — Pending |
| Section-header + inline comment style | File headers document purpose and override points; inline comments explain non-obvious lines only | — Pending |
| Single-repo under /etc/nerv — hosts/ subdir replaces /etc/nixos | path:.. fails in pure eval when /etc/nerv is a nix store symlink; root flake with self references avoids cross-flake path issues entirely | Decided 2026-03-06 |
| Home Manager user dotfiles in $HOME, not in this repo | System-level wiring (NixOS module) belongs here; user-specific packages/dotfiles belong in a user-owned repo under $HOME — different ownership, different change rate | Decided 2026-03-06 |

---
*Last updated: 2026-03-06 after initialization*
