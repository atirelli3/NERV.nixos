# External Integrations

**Analysis Date:** 2026-03-08

## Overview

NERV.nixos is a NixOS system configuration library. It has **no application-level external API integrations** (no HTTP clients, no SaaS SDKs, no webhook endpoints). All "integrations" are at the OS services layer — system daemons, hardware interfaces, and network protocols managed by NixOS modules.

---

## OS Services & Daemons

**OpenSSH (modules/services/openssh.nix):**
- Daemon: `services.openssh` — SSH server on configurable port (default: 2222)
- Key-based auth only by default (`PasswordAuthentication = false`)
- Root login disabled (`PermitRootLogin = "no"`)
- Config option: `nerv.openssh.port`, `nerv.openssh.allowUsers`

**endlessh tarpit (modules/services/openssh.nix):**
- Daemon: `services.endlessh` — SSH tarpit bound to port 22 by default
- Wastes bot connections with an infinitely slow SSH banner
- Config option: `nerv.openssh.tarpitPort` (default: 22)

**fail2ban (modules/services/openssh.nix):**
- Daemon: `services.fail2ban` — IP ban after repeated SSH failures
- Ban time: 24h, maxretry: 3 for SSH jail, exponential bantime-increment enabled
- LAN subnets excluded: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- Mode: `aggressive` (catches probes for invalid users)

**PipeWire (modules/services/pipewire.nix):**
- Daemon: `services.pipewire` — audio stack replacing PulseAudio
- ALSA compat: enabled (including 32-bit support for Steam/Wine)
- PulseAudio compat layer: enabled
- AirPlay sink: `libpipewire-module-raop-discover` — streams audio to RAOP receivers on LAN (UDP 6001-6002 opened)
- rtkit for realtime scheduling priority
- Low-latency defaults: 1024/48000 (~21ms quantum)

**Bluetooth (modules/services/bluetooth.nix):**
- Daemon: `hardware.bluetooth` via BlueZ
- GUI: `services.blueman` — GTK pairing manager
- mDNS advertisement: `services.avahi`
- WirePlumber config: SBC-XQ, mSBC, HSP/HFP roles enabled; auto-switch to headset profile disabled
- OBEX file transfer: `obexd --root=%h/Downloads --auto-accept` (user systemd service)
- MPRIS proxy: `mpris-proxy` user service (forwards headset media buttons to players)

**CUPS Printing (modules/services/printing.nix):**
- Daemon: `services.printing` — CUPS with `gutenprint` driver package
- Network discovery: `services.avahi` with `nssmdns4 = true` (.local hostname resolution)

**ClamAV (modules/system/security.nix):**
- Daemon: `services.clamav.daemon` (clamd) — real-time antivirus scanning
- Updater: `services.clamav.updater` (freshclam) — 24 definition update checks per day

**fwupd (modules/system/hardware.nix):**
- Daemon: `services.fwupd` — firmware updates via LVFS (Linux Vendor Firmware Service)
- Updates applied with: `fwupdmgr refresh && fwupdmgr upgrade`

**fstrim (modules/system/hardware.nix):**
- Timer: `services.fstrim` — weekly SSD TRIM
- Requires LUKS `allowDiscards = true` (set in `modules/system/boot.nix`)

---

## Security Services

**AppArmor (modules/system/security.nix):**
- `security.apparmor.enable = true` — Mandatory Access Control
- Confinement opt-in by default; strict mode available via `killUnconfinedConfinables`

**auditd (modules/system/security.nix):**
- `security.auditd.enable = true` — kernel syscall auditing
- Audit rules: `execve`, `openat`, `connect`, `setuid/setgid`, writes to `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`
- Logs to `/var/log/audit/audit.log`

**AIDE (modules/system/security.nix):**
- Package: `pkgs.aide` — file integrity monitor
- Monitored paths: `/boot /etc /bin /sbin /usr/bin /usr/sbin /lib /usr/lib`
- Daily check via `systemd.timers.aide-check` → `systemd.services.aide-check`
- Database: `/var/lib/aide/aide.db` (must be initialized manually post-install)

**TPM2 (modules/system/secureboot.nix):**
- `security.tpm2` with PKCS#11 and TCTI environment — only active when `nerv.secureboot.enable = true`
- Used for LUKS auto-unlock sealed to Secure Boot state (PCR 0+7)

---

## Secure Boot

**Lanzaboote (modules/system/secureboot.nix):**
- Input: `github:nix-community/lanzaboote`
- Replaces systemd-boot when `nerv.secureboot.enable = true`
- PKI bundle: `/var/lib/sbctl`
- Tooling: `sbctl` (key management), `tpm2-tss`, `tpm2-tools`
- Two-boot first-time enrollment sequence managed by `secureboot-enroll-keys.service` and `secureboot-enroll-tpm2.service`

---

## Network Protocols

| Protocol | Module | Purpose |
|---|---|---|
| SSH (port 2222 default) | `modules/services/openssh.nix` | Remote access |
| SSH tarpit (port 22 default) | `modules/services/openssh.nix` | Bot deterrent |
| mDNS / Avahi | `modules/services/bluetooth.nix`, `modules/services/printing.nix` | Local service discovery |
| RAOP / AirPlay (UDP 6001-6002) | `modules/services/pipewire.nix` | Audio streaming to LAN receivers |
| OBEX | `modules/services/bluetooth.nix` | Bluetooth file transfer |

---

## Hardware Interfaces

**CPU microcode (modules/system/hardware.nix):**
- AMD: `hardware.cpu.amd.updateMicrocode = true` + `amd_iommu=on iommu=pt`
- Intel: `hardware.cpu.intel.updateMicrocode = true` + `intel_iommu=on iommu=pt`
- Selected by `nerv.hardware.cpu` option

**GPU drivers (modules/system/hardware.nix):**
- NVIDIA: `xserver.videoDrivers = ["nvidia"]`, `hardware.nvidia.open = true` (Turing+/RTX 20xx+)
- AMD: `xserver.videoDrivers = ["amdgpu"]`
- Intel: `xserver.videoDrivers = ["intel"]`
- Selected by `nerv.hardware.gpu` option

**Firmware (modules/system/hardware.nix):**
- `hardware.enableRedistributableFirmware = true`
- `hardware.enableAllFirmware = true` (Wi-Fi, BT, GPU firmware blobs; requires `allowUnfree = true`)

---

## Data Storage

**Disk Layout (hosts/disko-configuration.nix):**
- Partitioning: GPT / EFI (1G, FAT32, label `NIXBOOT`) + LUKS (label `NIXLUKS`)
- LVM volumes: `swap` (NIXSWAP), `store` (NIXSTORE, ext4, `/nix`), `persist` (NIXPERSIST, ext4, `/persist`)
- Root `/` is NOT a persistent volume — it is a `tmpfs` in full-impermanence mode

**Persistent State (modules/system/impermanence.nix — full mode):**
- `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos` — persisted directories
- `/etc/machine-id`, SSH host keys (`ed25519` and `rsa`) — persisted files

**tmpfs (modules/system/impermanence.nix):**
- Minimal mode: `/tmp` and `/var/tmp` as tmpfs (25% RAM, `nosuid nodev`)
- Full mode: additionally `/` as tmpfs (2G limit)
- Optional per-user and extra-dir tmpfs mounts configurable via `nerv.impermanence.users` and `nerv.impermanence.extraDirs`

---

## Authentication & Identity

**SSH Auth:**
- Key-based only by default; password auth and keyboard-interactive auth disabled
- `PermitRootLogin = "no"` enforced
- Optional user allowlist via `nerv.openssh.allowUsers`

**Sudo:**
- `security.sudo.execWheelOnly = true` — only wheel-group members via setuid wrapper
- Primary users auto-added to `wheel` and `networkmanager` groups by `modules/system/identity.nix`

**Local User Auth:**
- Standard Linux PAM (NixOS defaults)
- No external identity provider (no LDAP, no SSO, no OAuth)

---

## CI/CD & Deployment

**Auto-upgrade (modules/system/nix.nix):**
- `system.autoUpgrade` pulls from `/etc/nixos#host` daily
- `allowReboot = false` — updates staged, manual reboot to apply
- No CI pipeline or remote build cache configured in the library itself

**Deployment method:**
- `nixos-rebuild switch --flake /etc/nixos#host` (aliased to `nrs` in `modules/services/zsh.nix`)
- Home Manager requires `--impure` flag because `~/home.nix` lives outside the flake boundary

---

## Home Manager Integration

**Source (home/default.nix):**
- Input: `github:nix-community/home-manager`
- Wired as `home-manager.nixosModules.home-manager`
- `useGlobalPkgs = true`, `useUserPackages = true`
- Each user listed in `nerv.home.users` must maintain `~/home.nix`
- `stateVersion` inherited from `osConfig.system.stateVersion` — user files need not set it

---

## Webhooks & External APIs

**Incoming:** None
**Outgoing:** None

This is a pure system configuration library with no HTTP server, no webhook receiver, and no outbound API calls.

---

*Integration audit: 2026-03-08*
