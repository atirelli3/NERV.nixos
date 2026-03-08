# Technology Stack

**Analysis Date:** 2026-03-08

## Languages

**Primary:**
- Nix (language) - All configuration, module logic, and build expressions. Used across every `.nix` file in the repository.

**Secondary:**
- Bash - Inline systemd service scripts (e.g., `secureboot-enroll-keys`, `secureboot-enroll-tpm2` in `modules/system/secureboot.nix`) and the `luks-cryptenroll` helper script.

## Runtime

**Environment:**
- NixOS (Linux) - x86_64-linux only. Declared in `flake.nix` under all three `nixosConfigurations` entries (`host`, `server`, `vm`).

**Package Manager:**
- Nix (flakes mode) - Channels are disabled (`nix.channel.enable = false` in `modules/system/nix.nix`). Flakes handle all input pinning.
- Lockfile: `flake.lock` (present — managed by Nix flake tooling)

## Frameworks

**Core:**
- NixOS Module System - The entire codebase is a NixOS module library. Every `.nix` file in `modules/` and `home/` is a NixOS module exposing `options.nerv.*` and `config` output.

**Disk Layout:**
- disko `v1.13.0` (`github:nix-community/disko`) - Declarative GPT/EFI/LUKS/LVM disk layout. Configuration in `hosts/disko-configuration.nix`.

**Home Management:**
- home-manager (`github:nix-community/home-manager`) - Wired as a NixOS module via `home/default.nix`. Tracks `nixpkgs` (pinned via `inputs.nixpkgs.follows`).

**Secure Boot:**
- lanzaboote (`github:nix-community/lanzaboote`) - UEFI Secure Boot bootloader. Optional — activated only when `nerv.secureboot.enable = true`. Replaces systemd-boot at runtime.

**Impermanence:**
- impermanence (`github:nix-community/impermanence`) - NixOS module for `environment.persistence`. Required only in `server` profile (`mode = "full"`). Desktop/VM use the built-in tmpfs approach from `modules/system/impermanence.nix`.

## Key Dependencies (Flake Inputs)

| Input | Source | Version Pin | Purpose |
|---|---|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-unstable` | flake.lock | All packages and NixOS modules |
| `lanzaboote` | `github:nix-community/lanzaboote` | flake.lock | Secure Boot bootloader |
| `home-manager` | `github:nix-community/home-manager` | flake.lock | User environment management |
| `disko` | `github:nix-community/disko/v1.13.0` | `v1.13.0` tag | Declarative disk partitioning |
| `impermanence` | `github:nix-community/impermanence` | flake.lock | Server-mode root-as-tmpfs |

All community inputs except `impermanence` declare `inputs.nixpkgs.follows = "nixpkgs"` to prevent duplicate nixpkgs instances.

## System Packages (Unconditional)

Declared in `modules/system/packages.nix` — present on all profiles:
- `git` - Version control; required for `nix flake` operations
- `fastfetch` - System info display with NERV ASCII logo

## System Packages (Conditional — security.nix)

Always enabled (unconditional security module):
- `lynis` - System hardening auditor
- `aide` - File integrity monitor (AIDE)

## System Packages (Conditional — secureboot.nix)

Only when `nerv.secureboot.enable = true`:
- `sbctl` - Secure Boot key management
- `tpm2-tss` - TPM2 Software Stack library
- `tpm2-tools` - TPM2 command-line utilities
- `luks-cryptenroll` - Custom helper script (inline `pkgs.writeTextFile`)

## System Packages (Conditional — pipewire.nix)

Only when `nerv.audio.enable = true`:
- `pwvucontrol` - Per-app volume control (GTK4/libadwaita)
- `helvum` - PipeWire patchbay

## System Packages (Conditional — zsh.nix)

Only when `nerv.zsh.enable = true`:
- `eza` - Modern `ls` replacement
- `fzf` - Fuzzy finder (shell integration via inline source)
- `zsh-syntax-highlighting` - Sourced manually in `interactiveShellInit`
- `zsh-history-substring-search` - Sourced manually in `interactiveShellInit`

## Kernel

- **Default:** `pkgs.linuxPackages_zen` (set via `lib.mkForce` in `modules/system/kernel.nix`, overrides the `linuxPackages_latest` fallback in `modules/system/boot.nix`)
- Zen kernel is optimized for desktop responsiveness / low latency
- Blacklisted modules: `cramfs freevxfs jffs2 hfs hfsplus udf dccp sctp rds tipc`

## Configuration

**Nix settings (modules/system/nix.nix):**
- `experimental-features = [ "nix-command" "flakes" ]`
- `allowed-users = [ "@wheel" ]`
- `trusted-users = [ "root" ]`
- `auto-optimise-store = true`
- `keep-outputs = true`, `keep-derivations = true`
- GC: automatic weekly, delete older than 20 days
- Store optimise: automatic weekly
- `nixpkgs.config.allowUnfree = true` (required for firmware blobs)

**Auto-upgrade:**
- Daily pull from `/etc/nixos#host` flake reference
- `allowReboot = false` — manual reboot required

**Boot config (modules/system/boot.nix):**
- initrd: systemd-based, LVM + LUKS
- LUKS device label: `NIXLUKS` (must stay in sync with `disko-configuration.nix` and `secureboot.nix`)
- Bootloader: systemd-boot (EFI), superseded by lanzaboote when secureboot enabled

## Platform Requirements

**Development:**
- NixOS or any Linux system with Nix flakes enabled
- `nixos-rebuild --impure` required when `nerv.home.enable = true` (reads `~/home.nix` outside flake boundary)

**Production / Deployment:**
- x86_64-linux only (all three `nixosConfigurations` are `system = "x86_64-linux"`)
- Target disk must be identified and set in `hosts/configuration.nix` (`disko.devices.disk.main.device`)
- All `PLACEHOLDER` values in `hosts/configuration.nix` must be replaced before `nixos-rebuild`

---

*Stack analysis: 2026-03-08*
