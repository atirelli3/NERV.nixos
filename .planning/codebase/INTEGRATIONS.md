# External Integrations

**Analysis Date:** 2026-03-10

## APIs & External Services

**Upstream Nix Registries:**
- `github:NixOS/nixpkgs/nixos-unstable` — primary package source; fetched by Nix daemon on build/upgrade
  - SDK/Client: Nix flake input (`nixpkgs` in `flake.nix`)
  - Auth: none (public GitHub)

**Community Flake Inputs (all declared in `flake.nix`):**
- `github:nix-community/lanzaboote` — Secure Boot bootloader library
  - SDK/Client: `lanzaboote.nixosModules.lanzaboote` imported in `flake.nix` `nixosConfigurations`
  - Auth: none (public GitHub)
- `github:nix-community/home-manager` — user dotfile management
  - SDK/Client: `home-manager.nixosModules.home-manager` imported in `flake.nix` `nixosConfigurations`
  - Auth: none (public GitHub)
- `github:nix-community/disko/v1.13.0` — declarative disk partitioning (pinned to v1.13.0)
  - SDK/Client: `disko.nixosModules.disko` imported in `flake.nix` `nixosConfigurations`; also invoked directly via `nix run github:nix-community/disko/v1.13.0` during install
  - Auth: none (public GitHub)
- `github:nix-community/impermanence` — `environment.persistence` bind-mount module
  - SDK/Client: `impermanence.nixosModules.impermanence` imported in `flake.nix` `nixosConfigurations`
  - Auth: none (public GitHub)

## Data Storage

**Databases:**
- None — this is a NixOS system configuration library; no application databases

**Filesystem Layouts (declared in `modules/system/disko.nix`):**

- BTRFS layout (desktop/laptop — `nerv.disko.layout = "btrfs"`):
  - Partition scheme: GPT → 1G FAT32 ESP (`/boot`, label `NIXBOOT`) → LUKS container (`NIXLUKS`) → BTRFS volume (`NIXBTRFS`)
  - Subvolumes: `/@` (`/`), `/@root-blank` (rollback baseline), `/@home` (`/home`), `/@nix` (`/nix`), `/@persist` (`/persist`), `/@log` (`/var/log`)
  - Mount options: `compress=zstd:3`, `noatime`, `space_cache=v2` on all subvolumes
  - LUKS: `cryptroot` device, `allowDiscards = true` (TRIM pass-through), label `NIXLUKS`

- LVM layout (server — `nerv.disko.layout = "lvm"`):
  - Partition scheme: GPT → 1G FAT32 ESP (`/boot`, label `NIXBOOT`) → LUKS container (`NIXLUKS`) → LVM PV → VG `lvmroot`
  - Logical volumes: `swap` (label `NIXSWAP`), `store` (ext4, `/nix`, label `NIXSTORE`), `persist` (ext4, `/persist`, label `NIXPERSIST`)
  - Sizes: configured via `nerv.disko.lvm.swapSize`, `nerv.disko.lvm.storeSize`, `nerv.disko.lvm.persistSize`

**Nix Store:**
- Location: `/nix/store` — managed by Nix daemon
- Optimization: `auto-optimise-store = true` (hardlinks) + weekly full pass (`nix.optimise`)
- GC: weekly, deletes generations older than 20 days (`modules/system/nix.nix`)

## Authentication & Identity

**Full Disk Encryption — LUKS:**
- Implementation: LUKS container `cryptroot` on `/dev/disk/by-label/NIXLUKS`
- Declared in: `modules/system/disko.nix` (format args) and shared unlock block
- Password unlock: `passwordFile = "/tmp/luks-password"` pre-seeded by install script during partitioning
- TPM2 auto-unlock: enrolled by `secureboot-enroll-tpm2` service in `modules/system/secureboot.nix`, binds to PCR 0+7 via `systemd-cryptenroll`

**Secure Boot — Lanzaboote + sbctl:**
- Implementation: `modules/system/secureboot.nix`
- Key storage: `/var/lib/sbctl` (must be persisted via `environment.persistence`)
- Enrollment: `secureboot-enroll-keys` systemd service runs `sbctl enroll-keys --microsoft` on first boot in Setup Mode
- TPM2 binding: `secureboot-enroll-tpm2` service runs `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7` on second boot
- Sentinels: `/var/lib/secureboot-keys-enrolled`, `/var/lib/secureboot-setup-done`
- Re-enrollment helper: `luks-cryptenroll` script in `systemPackages`

**SSH Authentication:**
- Implementation: `modules/services/openssh.nix`
- Method: key-based only by default (`PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`)
- Root login: disabled (`PermitRootLogin = "no"`)
- Host keys persisted via `environment.persistence` (`/etc/ssh/ssh_host_ed25519_key`, `ssh_host_rsa_key` and their `.pub` files)

**Machine Identity:**
- `/etc/machine-id` — persisted via `environment.persistence` in both impermanence modes (`modules/system/impermanence.nix`)

**User Management:**
- `nerv.primaryUser` list auto-wires `wheel` and `networkmanager` groups (`modules/system/identity.nix`)
- `sudo` restricted to wheel group only (`security.sudo.execWheelOnly = true` in `modules/system/security.nix`)
- Nix daemon access restricted to `@wheel` (`nix.settings.allowed-users` in `modules/system/nix.nix`)

## Monitoring & Observability

**Error Tracking:**
- None — no external error tracking service

**File Integrity (AIDE):**
- Implementation: `modules/system/security.nix`
- Tool: `pkgs.aide`
- Schedule: daily systemd timer (`aide-check.timer`)
- Config: `/etc/aide.conf` — monitors `/boot`, `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/lib`, `/usr/lib`; excludes `/nix`, `/var/log`, `/proc`, `/sys`, `/dev`, `/run`, `/tmp`
- Results: journald (`journalctl -u aide-check`)
- Database: `/var/lib/aide/aide.db`

**System Call Auditing (auditd):**
- Implementation: `modules/system/security.nix`
- Service: `security.auditd.enable = true`
- Rules: all `execve`, `openat`, `connect`, `setuid/setgid` syscalls; writes to `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`
- Output: `/var/log/audit/audit.log`

**Antivirus (ClamAV):**
- Implementation: `modules/system/security.nix`
- Service: `services.clamav.daemon.enable = true` (clamd), `services.clamav.updater.enable = true` (freshclam)
- Definition updates: 24 checks per day via freshclam

**Hardening Auditor (lynis):**
- Implementation: `modules/system/security.nix`
- Tool: `pkgs.lynis` in `systemPackages`
- Usage: manual — `sudo lynis audit system`

**Logs:**
- systemd journal (`journald`) — primary log sink
- `/var/log/audit/audit.log` — auditd syscall log
- `/var/log` persisted by `@log` BTRFS subvolume (BTRFS layout) or `environment.persistence` (full/LVM layout)

## CI/CD & Deployment

**Hosting:**
- Self-hosted — NixOS machines; the library repo is cloned to `/etc/nixos` on each managed host

**Auto-Upgrade:**
- Implementation: `modules/system/nix.nix`
- Service: `system.autoUpgrade.enable = true`
- Schedule: daily (`system.autoUpgrade.dates = "daily"`)
- Source: `flake = "/etc/nixos#host"` — pulls from the local flake at `/etc/nixos`
- Reboot: `allowReboot = false` — upgrades stage but require manual reboot

**CI Pipeline:**
- None — no remote CI; no GitHub Actions or other pipeline configuration detected

**Version Control:**
- Git — repository hosted at `github:atirelli3/NERV.nixos` (referenced in README installation instructions)
- Install path: `/etc/nixos` (cloned directly on target machine; this path is persisted via `environment.persistence` in both impermanence modes)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Network Services

**SSH Daemon (conditional on `nerv.openssh.enable`):**
- Implementation: `modules/services/openssh.nix`
- Port: `2222` (default; configurable via `nerv.openssh.port`)
- Tarpit: `endlessh` on port `22` (default; wastes scanner connections with infinite banner)
- Brute-force protection: `fail2ban` — 3 SSH failures in 10min → 24h ban; exponential growth capped at 168h; LAN subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) whitelisted

**Audio — AirPlay Sink (conditional on `nerv.audio.enable`):**
- Implementation: `modules/services/pipewire.nix`
- Protocol: RAOP (AirPlay) via `libpipewire-module-raop-discover`
- Firewall: `raopOpenFirewall = true` opens UDP 6001–6002 for discovery

**Bluetooth (conditional on `nerv.bluetooth.enable`):**
- Implementation: `modules/services/bluetooth.nix`
- OBEX file transfer: auto-accept to `~/Downloads`
- mDNS: `services.avahi.enable = true`
- MPRIS proxy: `mpris-proxy` systemd user service for headset media buttons

**Printing (conditional on `nerv.printing.enable`):**
- Implementation: `modules/services/printing.nix`
- Protocol: CUPS with network discovery via Avahi/mDNS (`nssmdns4 = true`)
- Default driver: `gutenprint`

**Firmware Updates (always on):**
- Implementation: `modules/system/hardware.nix`
- Service: `services.fwupd.enable = true` — LVFS firmware updates via `fwupdmgr`

**SSD TRIM (always on):**
- Implementation: `modules/system/hardware.nix`
- Service: `services.fstrim` — weekly TRIM; requires `allowDiscards = true` on LUKS device

## Environment Configuration

**Required host values (no defaults):**
- `nerv.hostname` — machine hostname
- `nerv.disko.layout` — `"btrfs"` | `"lvm"`
- `nerv.impermanence.mode` — `"btrfs"` | `"full"` (when `nerv.impermanence.enable = true`)
- `disko.devices.disk.main.device` — disk device path
- `nerv.hardware.cpu` — CPU vendor for microcode
- `nerv.hardware.gpu` — GPU vendor for drivers
- `nerv.locale.timeZone`, `nerv.locale.defaultLocale`, `nerv.locale.keyMap`
- LVM only: `nerv.disko.lvm.swapSize`, `nerv.disko.lvm.storeSize`, `nerv.disko.lvm.persistSize`

**Secrets location:**
- LUKS password: `/tmp/luks-password` — exists only during installation (pre-seeded by install script, not committed)
- SSH host keys: `/etc/ssh/ssh_host_*` — generated on first boot, persisted to `/persist` via `environment.persistence`
- Secure Boot keys: `/var/lib/sbctl` — generated and enrolled by `sbctl` on first boot with `nerv.secureboot.enable = true`
- No `.env` files exist in this repository

---

*Integration audit: 2026-03-10*
