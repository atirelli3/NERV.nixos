# Technology Stack

**Analysis Date:** 2026-03-06

## Languages

**Primary:**
- Nix (DSL) - All system configuration, module definitions, flake inputs/outputs

**Secondary:**
- Bash - Inline systemd service scripts (secureboot enrollment, AIDE checks, TPM2 enrollment)

## Runtime

**Environment:**
- NixOS (Linux) - Target OS for all configurations
- Target architecture: `x86_64-linux`
- NixOS state version: `25.11`

**Package Manager:**
- Nix (Flakes mode) - Dependency pinning via `flake.lock`
- Legacy channels: disabled (`nix.channel.enable = false` in `modules/nix.nix`)
- Experimental features enabled: `nix-command`, `flakes`

## Frameworks / Configuration System

**Core:**
- NixOS module system - Declarative OS configuration via `{ config, lib, pkgs, ... }:` module pattern
- Nix Flakes - Reproducible, pinned dependency management (`base/flake.nix`, `.template/flake.nix`, `.template/flake2.nix`)
- Disko - Declarative disk partitioning (`base/disko-configuration.nix`, `server/disko-configuration.nix`)

**Boot:**
- Lanzaboote `github:nix-community/lanzaboote` (pinned to `v0.4.1` in `.template/flake2.nix`, unpinned in `base/flake.nix`) - UEFI Secure Boot bootloader replacing systemd-boot
- systemd-initrd - Required for LVM-on-LUKS and crypttab integration (`boot.initrd.systemd.enable = true`)

**Impermanence:**
- `github:nix-community/impermanence` - tmpfs root with selective `/persist` bind-mounts (referenced in `.template/flake.nix`, implemented in `.template/configuration.nix`)

## Key System Packages

**Security Tools:**
- `sbctl` - Secure Boot key management (enroll, sign, status)
- `tpm2-tss` - TPM2 Software Stack (LUKS auto-unlock via TPM2)
- `tpm2-tools` - TPM2 command-line utilities
- `lynis` - System hardening auditor (`modules/security.nix`)
- `aide` - File integrity monitor (`modules/security.nix`)
- ClamAV (`services.clamav`) - Antivirus daemon + definition updater (`modules/security.nix`)

**Shell / CLI:**
- Zsh with `zsh-syntax-highlighting`, `zsh-history-substring-search`, `zsh-autosuggestions` (`modules/zsh.nix`)
- `starship` - Cross-shell prompt (`modules/zsh.nix`)
- `eza` - `ls` replacement (`modules/zsh.nix`)
- `fzf` - Fuzzy finder (`modules/zsh.nix`)
- Nerd Fonts: `caskaydia-cove`, `jetbrains-mono` (`modules/zsh.nix`)

**Audio:**
- PipeWire with ALSA, PulseAudio compat, WirePlumber session manager (`modules/pipewire.nix`)
- `pwvucontrol`, `helvum` - GUI audio management (`modules/pipewire.nix`)
- `bluez` - Bluetooth stack with OBEX and MPRIS proxy (`modules/bluetooth.nix`)
- `blueman` - Bluetooth GUI manager (`modules/bluetooth.nix`)

**Printing:**
- CUPS (`services.printing`) with `gutenprint` drivers (`modules/printing.nix`)
- Avahi mDNS for network printer discovery (`modules/printing.nix`, `modules/pipewire.nix`)

**Firmware:**
- `fwupd` - LVFS firmware update service (`modules/hardware.nix`)
- AMD CPU microcode (`hardware.cpu.amd.updateMicrocode = true`) (`modules/hardware.nix`)
- Redistributable + all firmware blobs enabled (`modules/hardware.nix`)

**Terminal font packages:**
- `terminus_font` - TTY PSF font (`base/configuration.nix`)

## Kernel

**Variant:**
- `base/configuration.nix`: `pkgs.linuxPackages_latest` (overridden by `modules/kernel.nix`)
- `modules/kernel.nix`: `pkgs.linuxPackages_zen` (desktop-optimised, low latency)
- Alternative noted in comments: `linuxPackages_hardened`

**Kernel Parameters (security hardening):**
- IOMMU: `amd_iommu=on`, `iommu=pt`
- Memory: `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1`, `page_alloc.shuffle=1`, `randomize_kstack_offset=on`
- CPU mitigations: `pti=on`, `tsx=off`
- Surface reduction: `vsyscall=none`, `debugfs=off`

**Blacklisted modules:**
- Filesystems: `cramfs`, `freevxfs`, `jffs2`, `hfs`, `hfsplus`, `udf`
- Network protocols: `dccp`, `sctp`, `rds`, `tipc`

## Configuration

**Build System:**
- Flake-based: `base/flake.nix` is the active flake; `.template/` directory holds reference/template variants
- NixOS rebuild command: `sudo nixos-rebuild switch --flake /etc/nixos#nixos`
- Flake update command: `sudo nix flake update /etc/nixos`

**Auto-upgrade:**
- Daily pulls from flake at `/etc/nixos#nixos` (`modules/nix.nix`)
- Manual reboot required (`allowReboot = false`)

**Nix store maintenance:**
- Garbage collection: weekly, deletes store paths older than 20 days
- Store optimisation: weekly dedup pass + incremental `auto-optimise-store`

**Unfree packages:**
- Allowed (`nixpkgs.config.allowUnfree = true` in `modules/nix.nix`)

## Nixpkgs Channel

**Source:** `github:NixOS/nixpkgs/nixos-unstable` (rolling unstable channel)

## Platform Requirements

**Development:**
- Nix with flakes enabled
- `x86_64-linux` target

**Production:**
- Bare-metal or VM with UEFI firmware supporting Secure Boot Setup Mode
- AMD CPU (microcode and IOMMU settings are AMD-specific)
- TPM2 chip (for LUKS auto-unlock sealed to Secure Boot state)
- SSD recommended (TRIM support configured throughout)

---

*Stack analysis: 2026-03-06*
