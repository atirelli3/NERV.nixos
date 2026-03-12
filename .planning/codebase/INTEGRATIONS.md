# External Integrations

**Analysis Date:** 2026-03-12

## APIs & External Services

**Firmware Updates:**
- LVFS (Linux Vendor Firmware Service) - Hardware firmware updates
  - Manager: `fwupd` service
  - Usage: Device firmware updates via `fwupdmgr refresh && fwupdmgr upgrade`

**Package Repository:**
- NixOS Nixpkgs (unstable channel) - Primary package source
  - Pinned via flake input: `github:NixOS/nixpkgs/nixos-unstable`

## Data Storage

**Databases:**
- Not used (system configuration library, not an application)

**File Storage:**
- Local filesystem only
  - BTRFS (desktop profile): Subvolume-based with snapshotting
  - LVM with ext4 (server profile): Standard block device

**Caching:**
- Nix store caching:
  - Auto-optimisation via `auto-optimise-store = true`
  - Weekly garbage collection (`--delete-older-than 20d`)
  - Weekly store optimisation pass
- System package cache: Standard nixpkgs substituters (binary cache)

## Authentication & Identity

**Auth Provider:**
- None (infrastructure library, not a service)

**SSH Key Management (when openssh enabled):**
- Key location: `/etc/ssh/ssh_host_*` (ED25519 and RSA)
- Persistence: Bind-mounted via impermanence module
- Optional Secure Boot integration: TPM2 LUKS auto-unlock (when secureboot enabled)

**Machine Identity:**
- `/etc/machine-id` - Stable unique machine identifier (persisted)
- Hostname: Defined via `nerv.hostname` option in per-host configuration

## Monitoring & Observability

**Error Tracking:**
- None (library, not application)

**Logs:**
- Systemd journal (journalctl)
- Syslog to `/var/log/`
- Audit logs: `/var/log/audit/audit.log` (auditd with custom rules)
- Service logs: Individual systemd service journals

**System Auditing:**
- Auditd (audit 4.x compatible): Tracks execve, openat, connect syscalls and privilege escalation
- AIDE: Daily file integrity checks for /boot, /etc, /bin, /sbin, /usr/bin, /usr/sbin, /lib, /usr/lib
- AppArmor: Mandatory Access Control with optional confinement policies

**Antivirus:**
- ClamAV daemon (clamd): Real-time scanning
- Freshclam: Daily virus definition updates (24 updates/day)

## CI/CD & Deployment

**Hosting:**
- Bare metal or hypervisor-agnostic (NixOS runs on any UEFI x86_64 system)

**System Updates:**
- Auto-upgrade: Daily flake updates via `system.autoUpgrade` (reboot deferred by default)
- Manual rebuild: `sudo nixos-rebuild switch --flake /etc/nixos#host`

**Installation:**
- Disko-based automated partitioning and formatting
- `nixos-install` with flake support
- Custom sbctl enrollment flow for Secure Boot (two-stage boot process)

## Environment Configuration

**Configuration Sources:**
- Flake inputs (declarative):
  - `nixpkgs` — package repository
  - `lanzaboote` — Secure Boot module
  - `home-manager` — user environment
  - `disko` — disk layout
  - `impermanence` — selective persistence
- NixOS options system: Per-host via `hosts/configuration.nix`
- Environment variables: No dotenv files (not an application)

**Secrets Management:**
- LUKS encryption: Root password via `/tmp/luks-password` (removed after installation)
- SSH host keys: Persisted via impermanence to `/persist/etc/ssh/`
- Secure Boot keys: Persisted to `/persist/var/lib/sbctl` (if secureboot enabled)
- No encrypted secret storage in repo (not applicable)

## Webhooks & Callbacks

**Incoming:**
- SSH (when openssh enabled): Port 2222 (configurable, port 22 reserved for endlessh tarpit)
  - Fail2ban rate limiting with exponential backoff (ban cap: 1 week)
  - Key-based auth enforced by default

**Outgoing:**
- None (library, not service)

## External Dependencies (Flake Inputs)

**Lanzaboote:**
- URL: `github:nix-community/lanzaboote`
- Purpose: Secure Boot bootloader implementation
- Activation: Requires `nerv.secureboot.enable = true`
- PKI location: `/var/lib/sbctl` (must persist)

**Home Manager:**
- URL: `github:nix-community/home-manager`
- Purpose: User-level NixOS module system
- Wiring: Via `home-manager.nixosModules.home-manager` in flake outputs
- User setup: Configure via `nerv.home.users` list

**Disko:**
- URL: `github:nix-community/disko/v1.13.0` (pinned to v1.13.0)
- Purpose: Declarative disk partitioning (GPT/LUKS/BTRFS or GPT/LUKS/LVM)
- Run command: `nix run github:nix-community/disko/v1.13.0 -- --mode destroy,format,mount --flake /tmp/nixos#host`

**Impermanence:**
- URL: `github:nix-community/impermanence`
- Purpose: Selective persistence layer for tmpfs-based root filesystems
- Module: `impermanence.nixosModules.impermanence`
- Usage modes:
  - `btrfs` — Root on BTRFS with snapshot rollback; /persist bind-mounts
  - `full` — Root as tmpfs; /persist holds all state

## Network Configuration

**Networking (implicit):**
- Systemd-networkd: Default network backend (no explicit config in this library)
- IPv4 hardening:
  - Reverse-path filtering enabled
  - SYN cookie protection
  - ICMP redirect rejection
  - Source route blocking
- IPv6 hardening:
  - ICMP redirect rejection
  - Source route blocking

**Service Ports (when enabled):**
- SSH: 2222 (openssh) + 22 (endlessh tarpit)
- CUPS: 631 (printing daemon)
- PipeWire RAOP: 6001-6002 UDP (AirPlay audio discovery)

---

*Integration audit: 2026-03-12*
