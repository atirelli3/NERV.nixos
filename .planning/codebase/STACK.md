# Technology Stack

**Analysis Date:** 2026-03-10

## Languages

**Primary:**
- Nix (NixOS module system) — all configuration, module definitions, disk layouts, service wiring
- Bash (inline scripts) — initrd rollback script (`modules/system/disko.nix`), secureboot first-boot
  services (`modules/system/secureboot.nix`), LUKS re-enrollment helper script (`modules/system/secureboot.nix`)

## Runtime

**Environment:**
- NixOS `nixos-unstable` channel — pinned via `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"` in `flake.nix`
- Target architecture: `x86_64-linux` (both `host` and `server` nixosConfigurations)
- `system.stateVersion = "25.11"` declared in `hosts/configuration.nix`

**Package Manager:**
- Nix (flakes mode) — `experimental-features = [ "nix-command" "flakes" ]` set in `modules/system/nix.nix`
- Legacy channels: disabled — `nix.channel.enable = false` in `modules/system/nix.nix`
- Lockfile: `flake.lock` (present — managed by `nix flake update`)

## Frameworks

**Core:**
- NixOS module system — all configuration expressed as `{ config, lib, pkgs, ... }:` modules with
  `options.*` / `config.*` separation; primary framework for every `.nix` file under `modules/`
- Nix flakes — entry point is `flake.nix`; exports `nixosModules` and `nixosConfigurations`

**Disk Layout:**
- disko `v1.13.0` — `github:nix-community/disko/v1.13.0` (pinned); declarative GPT/LUKS/BTRFS
  and GPT/LUKS/LVM layouts defined in `modules/system/disko.nix`

**Impermanence:**
- nix-community/impermanence — `github:nix-community/impermanence` (no release tags, HEAD);
  provides `environment.persistence` bind-mount API used in `modules/system/impermanence.nix`

**Home Environment:**
- Home Manager — `github:nix-community/home-manager` with `inputs.nixpkgs.follows = "nixpkgs"`;
  wired as a NixOS module in `home/default.nix`; user config loaded from `~/home.nix` (outside flake,
  requires `nixos-rebuild --impure`)

**Secure Boot:**
- Lanzaboote — `github:nix-community/lanzaboote` with `inputs.nixpkgs.follows = "nixpkgs"`;
  replaces systemd-boot when `nerv.secureboot.enable = true`; configured in `modules/system/secureboot.nix`

## Key Dependencies

**Critical (flake inputs):**
- `nixpkgs` (`nixos-unstable`) — base package set and NixOS module library; all `pkgs.*` and `lib.*` calls
- `disko` `v1.13.0` — declarative disk partitioning; `disko.nixosModules.disko` wired in both nixosConfigurations
- `impermanence` (HEAD) — `environment.persistence` bind-mount module; `impermanence.nixosModules.impermanence`
  in both nixosConfigurations
- `home-manager` (unstable, follows nixpkgs) — user dotfile management; `home-manager.nixosModules.home-manager`
- `lanzaboote` (unstable, follows nixpkgs) — Secure Boot bootloader; `lanzaboote.nixosModules.lanzaboote`

**System Packages (always-on):**
- `pkgs.git` — version control; enabled via `programs.git.enable = true` in `modules/system/packages.nix`
- `pkgs.fastfetch` — system info display; `modules/system/packages.nix`

**Conditional Packages (service-dependent):**
- `pkgs.btrfs-progs` — added to initrd store paths when `nerv.disko.layout = "btrfs"`; `modules/system/disko.nix`
- `pkgs.sbctl`, `pkgs.tpm2-tss`, `pkgs.tpm2-tools` — Secure Boot management; `modules/system/secureboot.nix`
- `pkgs.eza`, `pkgs.fzf` — shell utilities; added when `nerv.zsh.enable = true`; `modules/services/zsh.nix`
- `pkgs.pwvucontrol`, `pkgs.helvum` — audio tools; added when `nerv.audio.enable = true`; `modules/services/pipewire.nix`
- `pkgs.zsh-syntax-highlighting`, `pkgs.zsh-history-substring-search` — shell plugins; sourced manually in
  `interactiveShellInit` in `modules/services/zsh.nix`
- `pkgs.gutenprint` — printer driver; `modules/services/printing.nix`
- `pkgs.lynis`, `pkgs.aide` — security auditing tools; always-on via `modules/system/security.nix`
- `pkgs.terminus_font` — TTY console font; `modules/system/identity.nix`

## Configuration

**Nix daemon settings (`modules/system/nix.nix`):**
- `auto-optimise-store = true` — deduplicates store after each build
- `gc.automatic = true` with `--delete-older-than 20d` weekly
- `keep-outputs = true`, `keep-derivations = true` — preserves dev shell sources
- `allowed-users = [ "@wheel" ]`, `trusted-users = [ "root" ]`
- `system.autoUpgrade` — enabled daily, pulls from `/etc/nixos#host`, `allowReboot = false`

**Host-level configuration (`hosts/configuration.nix`):**
- All values are `PLACEHOLDER` — must be filled per-machine before first boot
- Required: `nerv.hostname`, `nerv.primaryUser`, `nerv.hardware.cpu`, `nerv.hardware.gpu`,
  `nerv.locale.*`, `disko.devices.disk.main.device`, `nerv.disko.layout`, `nerv.disko.lvm.*` (if LVM)

**nixpkgs:**
- `nixpkgs.config.allowUnfree = true` — required for proprietary firmware and drivers; `modules/system/nix.nix`

**Build:**
- `flake.nix` — single entry point; no separate build config files
- Rebuild command (aliased in zsh): `sudo nixos-rebuild switch --flake /etc/nixos#host`

## Platform Requirements

**Development:**
- Nix with flakes enabled (`nix-command` + `flakes` experimental features)
- Target dev machine: any NixOS or nix-capable host that can run `nix flake check`
- `nix flake check` — validates module evaluation before deploy

**Production:**
- Target OS: NixOS `x86_64-linux`
- Two deployment profiles defined in `flake.nix`:
  - `host` — desktop/laptop; BTRFS layout, audio, bluetooth, printing, impermanence (btrfs mode)
  - `server` — headless server; LVM layout, openssh only, impermanence (full/tmpfs mode)
- Secure Boot (optional): requires UEFI with Setup Mode accessible; `nerv.secureboot.enable = false` by default

---

*Stack analysis: 2026-03-10*
