# External Integrations

**Analysis Date:** 2026-03-06

## Package Registries & Upstream Sources

**Nixpkgs:**
- Source: `github:NixOS/nixpkgs/nixos-unstable` (declared in all flakes)
- Role: Primary package set for all system packages, services, and modules
- Pin: Managed via `flake.lock` (regenerated with `nix flake update`)

**Nix Community Flakes:**
- `github:nix-community/lanzaboote` - UEFI Secure Boot bootloader integration
  - Active pin in `.template/flake2.nix`: `v0.4.1`
  - Unpinned (follows nixos-unstable) in `base/flake.nix`
  - Tracks nixpkgs via `inputs.nixpkgs.follows = "nixpkgs"`
- `github:nix-community/impermanence` - tmpfs root + selective persistence
  - Referenced in `.template/flake.nix`
  - Not yet wired into `base/flake.nix` (planned for server/advanced config)

## Firmware & Hardware Update Services

**LVFS (Linux Vendor Firmware Service):**
- Integration: `services.fwupd.enable = true` (`modules/hardware.nix`)
- Purpose: OTA firmware updates for supported laptops, drives, and peripherals
- Usage: `fwupdmgr refresh && fwupdmgr upgrade`
- Network access: Fetches metadata and firmware from `fwupd.org` / LVFS CDN

**AMD Microcode:**
- Source: Upstream AMD microcode blobs via nixpkgs (`hardware.cpu.amd.updateMicrocode = true`)
- Applied: Early in initrd boot

**Redistributable Firmware:**
- `hardware.enableRedistributableFirmware = true` and `hardware.enableAllFirmware = true`
- Covers: Wi-Fi cards, GPUs, peripheral firmware blobs from nixpkgs

## Security & Antivirus

**ClamAV (Virus Definitions):**
- Daemon: `services.clamav.daemon.enable = true` (`modules/security.nix`)
- Updater: `services.clamav.updater.enable = true` — `freshclam` fetches definitions
- Update frequency: 24 checks per day
- Network access: ClamAV mirror CDN (`database.clamav.net`)

## Secure Boot Chain

**Microsoft UEFI CA:**
- `sbctl enroll-keys --microsoft` (`modules/secureboot.nix`, `.template/secureboot-configuration.nix`)
- Enrolls Microsoft's certificate authority alongside custom keys
- Purpose: Allows dual-boot compatibility and signed third-party drivers
- Triggered: First-boot systemd oneshot service `secureboot-enroll-keys`

**TPM2 (Local Hardware):**
- Not a network integration — local chip communication via `tpm2-tss`
- LUKS PKCS#11 binding: `security.tpm2.pkcs11.enable = true`
- TCTI environment: `security.tpm2.tctiEnvironment.enable = true`
- Auto-unlock sealed to PCRs 0+7 (firmware + Secure Boot state measurement)

## Remote Access

**OpenSSH:**
- Enabled: `services.openssh.enable = true` (`modules/openssh.nix`)
- Port: `2222` (non-standard, port 22 reserved for tarpit)
- Auth: Public key only (`PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`)
- Root login: Disabled
- Key type recommended: `ed25519` (per inline docs in `modules/openssh.nix`)

## Network Security Services

**Endlessh (SSH Tarpit):**
- `services.endlessh.enable = true` (`modules/openssh.nix`)
- Listens on port 22 (the default SSH attack target)
- Purpose: Traps and wastes bot scanner connections with infinitely slow banner
- No external network dependency; purely local listener

**Fail2ban:**
- `services.fail2ban.enable = true` (`modules/openssh.nix`)
- SSH jail: `aggressive` mode, 3 failures within 10 minutes → 24h ban
- Ban escalation: Exponential for repeat offenders, capped at 168h (1 week)
- Exemptions: RFC 1918 private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
- No external IP reputation lookup configured

## Audio Network Integrations

**AirPlay (RAOP) Sink:**
- `libpipewire-module-raop-discover` loaded in PipeWire (`modules/pipewire.nix`)
- Firewall: UDP ports 6001-6002 opened (`raopOpenFirewall = true`)
- Discovery: Avahi mDNS on local network
- Purpose: Stream audio output to AirPlay receivers on LAN

**Avahi (mDNS/DNS-SD):**
- `services.avahi.enable = true` (`modules/pipewire.nix`)
- `services.avahi.nssmdns4 = true` (`modules/printing.nix`)
- Purpose: Local network printer and AirPlay device discovery (`.local` hostnames)
- Scope: LAN only, no external DNS

## Bluetooth

**BlueZ (Linux Bluetooth Stack):**
- `hardware.bluetooth.enable = true` (`modules/bluetooth.nix`)
- OBEX file transfer: `obexd --root=%h/Downloads --auto-accept`
- MPRIS proxy: Forwards headset media buttons to compatible players
- Codecs enabled: SBC-XQ, mSBC, hardware volume control
- Roles: `hsp_hs`, `hsp_ag`, `hfp_hf`, `hfp_ag` (call audio)

## Printing

**CUPS + Network Printers:**
- `services.printing.enable = true` (`modules/printing.nix`)
- Driver: `gutenprint` (multi-brand)
- Discovery: Avahi mDNS (`.local` printer hostnames)
- Optional declarative printer URI pattern: `ipp://printer.local/ipp/print`

## NixOS Auto-Upgrade

**NixOS flake auto-upgrade:**
- `system.autoUpgrade.enable = true` (`modules/nix.nix`)
- Source: Reads flake from local path `/etc/nixos#nixos`
- Schedule: Daily
- Network access: Fetches updated nixpkgs and flake inputs from GitHub
- Reboot: Manual only (`allowReboot = false`)

## Webhooks & Callbacks

**Incoming:** None configured.

**Outgoing:** None configured.

## Authentication & Identity

**Auth Provider:** No external auth provider. SSH key-based authentication only.

**User management:**
- Declarative via NixOS (`users.users.*` in configuration files)
- Passwords: hashed password file at `/persist/passwords/<user>` (impermanence template)
- SSH keys: Inline in `users.users.<name>.openssh.authorizedKeys.keys` or via `keyFiles`

## Secrets Location

- No secrets management tool (e.g., agenix, sops-nix) is configured in the current active `base/flake.nix`
- LUKS password seeded at install time via `/tmp/luks-password` (consumed by Disko, not persisted)
- Hashed user passwords stored at `/persist/passwords/<user>` (impermanence template only)
- SSH host keys persisted at `/etc/ssh/ssh_host_ed25519_key` and `/etc/ssh/ssh_host_rsa_key` via impermanence

## Environment Configuration

**Required for deployment:**
- No `.env` files — all configuration is declarative Nix
- Hardware-specific: `/etc/nixos/hardware-configuration.nix` (generated by `nixos-generate-config`, not tracked in repo)
- Disk device paths: Placeholders (`/dev/DISK`, `SIZE_RAM * 2`) must be replaced before running Disko

---

*Integration audit: 2026-03-06*
