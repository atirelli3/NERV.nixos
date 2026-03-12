# Technology Stack

**Analysis Date:** 2026-03-12

## Languages

**Primary:**
- Nix - Declarative system configuration language for NixOS
- Bash - Shell scripting for helper scripts and systemd services

## Runtime

**Environment:**
- NixOS (Linux-based declarative OS)
- Linux kernel - Latest version by default (configurable between zen, hardened variants)
- Systemd - Init system and service management

**Package Manager:**
- Nix package manager (nixpkgs-unstable channel)
- Flakes - Declarative dependency pinning and reproducible builds

## Frameworks

**Core System:**
- NixOS modules system - Composable declarative system configuration
- Home Manager (nix-community/home-manager) - User environment and dotfile management

**Boot & Disk:**
- Disko (nix-community/disko v1.13.0) - Declarative disk partitioning and formatting (BTRFS or LVM)
- Lanzaboote (nix-community/lanzaboote) - Secure Boot bootloader using systemd-boot as base

**State Management:**
- Impermanence (nix-community/impermanence) - Selective persistence for tmpfs-based filesystems
- BTRFS snapshots - Automatic rollback via snapshot restoration on boot

**Testing/Tools:**
- sbctl - Secure Boot key management and signing

## Key Dependencies

**Critical (always enabled):**
- `nixpkgs` (unstable) - Base package repository
- `git` - Version control (built-in system package)
- `fastfetch` - System information display
- `zsh` (enabled by default) - Interactive shell with history, completion, fzf integration
- `eza` - Modern `ls` replacement with git integration
- `fzf` - Fuzzy finder for command-line completion and navigation

**Security (always enabled):**
- `apparmor` - Mandatory Access Control enforcement
- `auditd` - System call auditing (audit 4.x compatible)
- `clamav` (clamd + freshclam) - Antivirus daemon with automatic definition updates
- `aide` - File integrity monitoring
- `lynis` - System hardening auditor
- `linux-zen` kernel (default) - Desktop-optimized kernel with low-latency tuning
- `sbctl` - Secure Boot key generation and enrollment (only on secureboot.enable)
- `tpm2-tss`, `tpm2-tools` - TPM2 LUKS auto-unlock utilities (only on secureboot.enable)

**Optional Services (disabled by default):**
- `openssh` - SSH daemon with endlessh tarpit and fail2ban
- `endlessh` - SSH banner slowdown tarpit (binds to port 22)
- `fail2ban` - Rate limiting and IP banning (SSH-specific rules)
- `pipewire` - Audio server stack
  - `pwvucontrol` - PipeWire volume control GUI
  - `crosspipe` - PipeWire patchbay (replaces deprecated helvum)
- `pulseaudio` - PulseAudio compatibility layer (via PipeWire)
- `alsa-utils` - ALSA low-level audio tools
- `blueman` - Bluetooth device pairing and management GUI
- `avahi` - mDNS (Bonjour) service discovery
- `cups` - CUPS printing daemon
- `gutenprint` - Printer driver package (default)
- `hplip`, `brlaser` - Alternate printer drivers (optional)

**Infrastructure/Monitoring:**
- `systemd-tmpfiles` - Automatic tmpfile and directory management
- `systemd` (native) - Timer-based scheduling, socket activation
- `fwupd` - Firmware update manager (LVFS)
- `btrfs-progs` - BTRFS filesystem utilities (required in initrd for rollback)

## Configuration

**Environment:**
- NixOS configuration: `flake.nix` (flake-based, no legacy channels)
- Per-host configuration: `hosts/configuration.nix` (machine identity)
- Module configuration: `.nix` files in `modules/` directories

**Key Configuration Methods:**
- Flake inputs: External dependencies (nixpkgs, lanzaboote, home-manager, disko, impermanence)
- NixOS options system: Configuration via `options.*` and `config.*` in modules
- Environment variables: Sourced from system environment
- Luks password: Pre-seeded via `/tmp/luks-password` during installation

**Build:**
- `flake.lock` - Lock file for reproducible builds
- No traditional build system (nix build or nixos-rebuild)
- Two profiles:
  - `host` — BTRFS desktop/laptop (openssh, audio, bluetooth, printing enabled by default)
  - `server` — LVM headless (impermanence full mode, system-only tmpfs)

## Platform Requirements

**Development:**
- NixOS system with flakes support
- x86_64-linux architecture (primary target)
- 4GB+ RAM for initial builds

**Production:**
- NixOS running on bare metal or VM
- EFI/UEFI firmware support (systemd-boot is UEFI-only)
- Secure Boot capable system (optional, via Lanzaboote + TPM2)
- Either:
  - BTRFS filesystem (desktop profile, requires subvolume support)
  - LVM with ext4 (server profile)
- LUKS2 encryption on root partition

**Hardware Support:**
- CPU options: AMD (microcode + IOMMU), Intel (microcode + IOMMU), or generic
- GPU options: NVIDIA (open drivers Turing+), AMD (amdgpu), Intel, or none
- Bluetooth: Optional, requires hardware adapter
- Printing: Optional, requires compatible printer and driver

---

*Stack analysis: 2026-03-12*
