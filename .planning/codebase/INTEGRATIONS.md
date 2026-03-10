# External Integrations

**Analysis Date:** 2026-03-10

## Upstream Nix Flake Inputs

These are the only external dependencies. All are fetched by Nix at build/eval time — no runtime
network calls from the system configuration itself.

**NixOS Package Set:**
- `nixpkgs` — `github:NixOS/nixpkgs/nixos-unstable`
  - Auth: none (public GitHub)
  - Role: base package set for all `pkgs.*` and `lib.*` usage across every module

**Disk Layout:**
- `disko` — `github:nix-community/disko/v1.13.0` (pinned by tag)
  - Follows: `nixpkgs`
  - Role: `disko.nixosModules.disko` — declarative GPT/LUKS partitioning in `modules/system/disko.nix`

**Impermanence:**
- `impermanence` — `github:nix-community/impermanence` (HEAD, no nixpkgs input — no follows)
  - Role: `impermanence.nixosModules.impermanence` — `environment.persistence` bind-mounts in
    `modules/system/impermanence.nix`

**Home Manager:**
- `home-manager` — `github:nix-community/home-manager`
  - Follows: `nixpkgs`
  - Role: `home-manager.nixosModules.home-manager` — user dotfile management wired in `home/default.nix`

**Secure Boot:**
- `lanzaboote` — `github:nix-community/lanzaboote`
  - Follows: `nixpkgs`
  - Role: `lanzaboote.nixosModules.lanzaboote` — replaces systemd-boot when `nerv.secureboot.enable = true`;
    configured in `modules/system/secureboot.nix`

## Data Storage

**Databases:**
- None — this is a NixOS configuration library, not an application

**Filesystem layouts (target machine, declared in `modules/system/disko.nix`):**

BTRFS layout (`nerv.disko.layout = "btrfs"` — desktop/laptop):
- `/boot` — vfat, label `NIXBOOT`, 1G ESP
- LUKS container — label `NIXLUKS`, TRIM enabled
- BTRFS pool — label `NIXBTRFS`, subvolumes:
  - `/@` → `/` (compress=zstd:3)
  - `/@root-blank` → no mountpoint (rollback baseline)
  - `/@home` → `/home`
  - `/@nix` → `/nix`
  - `/@persist` → `/persist`
  - `/@log` → `/var/log`

LVM layout (`nerv.disko.layout = "lvm"` — server):
- `/boot` — vfat, label `NIXBOOT`, 1G ESP
- LUKS container — label `NIXLUKS`, TRIM enabled
- LVM VG `lvmroot` with LVs:
  - `swap` — label `NIXSWAP`
  - `store` → `/nix` — ext4, label `NIXSTORE`
  - `persist` → `/persist` — ext4, label `NIXPERSIST`

**File Storage:**
- Local filesystem only — no cloud storage integration

**Caching:**
- Nix binary cache — default `cache.nixos.org` (built into nixpkgs, not configured explicitly here)
- No application-level caching

## Authentication & Identity

**SSH (when `nerv.openssh.enable = true`):**
- Implementation: `modules/services/openssh.nix`
- Key-based auth only by default (`PasswordAuthentication = false`, `KbdInteractiveAuth = false`)
- SSH daemon on non-standard port (default `2222`); port `22` reserved for endlessh tarpit
- Host keys persisted to `/persist` via `environment.persistence` in `modules/system/impermanence.nix`:
  - `/etc/ssh/ssh_host_ed25519_key` + `.pub`
  - `/etc/ssh/ssh_host_rsa_key` + `.pub`
- Machine identity: `/etc/machine-id` persisted to `/persist`

**Secure Boot / LUKS (when `nerv.secureboot.enable = true`):**
- Implementation: `modules/system/secureboot.nix`
- Lanzaboote — PKI bundle at `/var/lib/sbctl` (persisted via `environment.persistence`)
- TPM2 LUKS auto-unlock — sealed to PCRs `0+7` via `systemd-cryptenroll`
- First-boot automation: two-phase systemd services:
  - `secureboot-enroll-keys.service` — enrolls SB keys and reboots
  - `secureboot-enroll-tpm2.service` — binds LUKS to TPM2 on second boot
- Re-enrollment helper: `luks-cryptenroll` script placed in `environment.systemPackages`
- No external auth provider — all local/TPM2

**sudo:**
- `security.sudo.execWheelOnly = true` — only `wheel` group members may use sudo (`modules/system/security.nix`)

## Monitoring & Observability

**Antivirus:**
- ClamAV — `services.clamav.daemon.enable = true`, `services.clamav.updater.enable = true`
  - Definition updates: 24 checks/day via `freshclam`
  - Configured in `modules/system/security.nix`

**File Integrity:**
- AIDE — `pkgs.aide` installed via `modules/system/security.nix`
  - Daily check timer: `systemd.timers.aide-check` → `systemd.services.aide-check`
  - Config at `/etc/aide.conf` (monitors `/boot`, `/etc`, `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/lib`, `/usr/lib`)
  - Database: `/var/lib/aide/aide.db` — must be initialized manually after first boot
  - Nix store explicitly excluded (`!/nix`) to avoid false positives

**Audit:**
- `security.auditd.enable = true` + `security.audit.enable = true` — system call auditing
  - Logs to `/var/log/audit/audit.log`
  - Rules monitor: `execve`, `openat`, `connect`, `setuid/setgid`, writes to `/etc/passwd`,
    `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`
  - Configured in `modules/system/security.nix`

**Security Audit Tool:**
- Lynis — `pkgs.lynis` installed via `modules/system/security.nix`
  - Manual only: `sudo lynis audit system`

**Error Tracking:**
- None (NixOS system config, not an application)

**Logs:**
- systemd journal (`journald`) — default NixOS logging
- `/var/log` persisted via `@log` BTRFS subvolume (btrfs mode) or `environment.persistence` (full mode)

## Network Services (Runtime)

**SSH Tarpit:**
- endlessh — `services.endlessh.enable = true` on port `22` (tarpitPort)
  - Configured via `nerv.openssh.tarpitPort` option in `modules/services/openssh.nix`
  - Firewall port opened automatically

**Fail2ban:**
- `services.fail2ban` — rate-limits and bans IPs after SSH brute force attempts
  - Global: `maxretry = 5`, `bantime = 24h`
  - SSHD jail: `maxretry = 3`, `findtime = 600s`, mode `aggressive`
  - Exponential ban increase, max `168h` (1 week), across all jails
  - Private subnets exempted: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
  - Configured in `modules/services/openssh.nix`

**mDNS / Avahi:**
- `services.avahi.enable = true` — mDNS for network printer discovery (printing module) and
  Bluetooth service advertisement (bluetooth module)
- Configured in both `modules/services/printing.nix` and `modules/services/bluetooth.nix`

**PipeWire / Audio:**
- `services.pipewire` — local audio stack; no network integration beyond AirPlay RAOP sink
  - AirPlay (RAOP): `libpipewire-module-raop-discover`; UDP 6001-6002 opened by `raopOpenFirewall = true`
  - Configured in `modules/services/pipewire.nix`

**CUPS Printing:**
- `services.printing` — local CUPS daemon; discovers printers via Avahi/mDNS
  - Driver: `gutenprint` (multi-brand)
  - Configured in `modules/services/printing.nix`

**NetworkManager:**
- `networking.networkmanager.enable = true` — declared in `hosts/configuration.nix`
  - `wheel` / `networkmanager` groups assigned to `nerv.primaryUser` entries via `modules/system/identity.nix`

**Firmware Updates:**
- `services.fwupd.enable = true` — pulls device firmware from Linux Vendor Firmware Service (LVFS)
  - Applied manually: `fwupdmgr refresh && fwupdmgr upgrade`
  - Configured in `modules/system/hardware.nix`

**SSD TRIM:**
- `services.fstrim.enable = true` — weekly TRIM via systemd timer
  - Requires `allowDiscards = true` on the LUKS device (set in `modules/system/disko.nix`)
  - Configured in `modules/system/hardware.nix`

## CI/CD & Deployment

**Hosting:**
- Self-hosted NixOS target machines — no cloud hosting

**CI Pipeline:**
- None detected — no `.github/workflows/`, `.cirrus.yml`, or similar CI config

**Auto-upgrade:**
- `system.autoUpgrade` — daily pull from `/etc/nixos#host` flake, `allowReboot = false`
  - Staged updates require manual reboot to activate
  - Configured in `modules/system/nix.nix`

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Environment Configuration

**Required host values (all `PLACEHOLDER` in `hosts/configuration.nix`):**
- `nerv.hostname` — machine hostname
- `nerv.primaryUser` — list of primary user names
- `nerv.hardware.cpu` — `"amd"` | `"intel"` | `"other"`
- `nerv.hardware.gpu` — `"amd"` | `"nvidia"` | `"intel"` | `"none"`
- `nerv.locale.timeZone`, `nerv.locale.defaultLocale`, `nerv.locale.keyMap`
- `disko.devices.disk.main.device` — block device path (e.g. `/dev/nvme0n1`)
- `nerv.disko.layout` — `"btrfs"` | `"lvm"`
- `nerv.disko.lvm.swapSize`, `nerv.disko.lvm.storeSize`, `nerv.disko.lvm.persistSize` (LVM only)

**No `.env` files** — all configuration is declarative Nix; no runtime environment variables

**Secrets location:**
- LUKS passphrase: `/tmp/luks-password` — pre-seeded by install script, used only during `disko` run
- SSH host keys: generated at first boot, persisted to `/persist/etc/ssh/`
- Secure Boot PKI: generated by `sbctl`, stored at `/persist/var/lib/sbctl/`

---

*Integration audit: 2026-03-10*
