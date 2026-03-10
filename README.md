<p align="center">
  <img src="docs/assets/nerv.nixos-logo.png" width="460" alt="NERV.nixos logo" />
</p>

<h1 align="center">NERV.nixos</h1>

<p align="center">
  An opinionated, composable NixOS base library — declare your machine identity, get a hardened system out of the box.
</p>

---

## What is NERV.nixos?

NERV.nixos is a NixOS flake that provides hardened system defaults as composable modules. Instead of managing a monolithic `configuration.nix`, you write a minimal host file that declares only what is specific to your machine — CPU, GPU, hostname, locale, disk device — and inherit a secure, well-documented system automatically.

**Core value:** you declare machine-specific parameters; NERV handles the rest.

### What NERV provides

- Hardened kernel (Zen) with memory, CPU, and network security params
- Full disk encryption via LUKS-on-LVM, declaratively provisioned by Disko
- Secure Boot via Lanzaboote with automatic TPM2 LUKS bind across two boot stages
- AppArmor, auditd, ClamAV, and AIDE file integrity monitoring — always on
- SSH daemon hardened with endlessh tarpit, fail2ban with exponential ban growth
- PipeWire audio stack with low-latency defaults, AirPlay sink, and ALSA/PulseAudio compat
- Bluetooth (OBEX), printing (CUPS + Avahi), ZSH with autosuggestions
- Impermanence — `btrfs` mode uses BTRFS rollback to reset `/` on every boot, persisting state to `/persist` (@persist subvolume); `full` mode wipes `/` on reboot and persists state to `/persist` (LVM)
- Home Manager NixOS wiring — each user owns `~/home.nix`; NERV imports it automatically
- Typed NixOS module options (`nerv.*`) for every user-configurable parameter

### What NERV does NOT provide

- DE/WM/DM configuration — belongs in your host flake
- Home Manager dotfiles — you own `~/home.nix`; NERV only wires it in
- Multi-user example templates — covered by the three built-in profiles

### Profiles

Three profiles are defined inline in `flake.nix`. Pick the one that matches your target:

| Profile | Use case | Key differences |
|---------|----------|-----------------|
| `host`   | Desktop / laptop | Audio, Bluetooth, printing, Lanzaboote, BTRFS impermanence (rollback on boot) |
| `server` | Headless server  | SSH only, LVM layout, full impermanence (`/` as tmpfs, state on `/persist`) |

---

## Installation

### A — New system (NixOS Live ISO)

> **Before you begin:** find your disk name (`lsblk -d -o NAME,SIZE,MODEL`) and fill `hosts/disko-configuration.nix` — replace every `PLACEHOLDER` and `SIZE` value. Read the warning block at the top of that file.

```bash
# 1. Boot the NixOS minimal ISO and get a root shell.

# 2. Clone NERV.nixos into the standard NixOS config location.
mkdir -p /mnt/etc/nixos
git clone https://github.com/atirelli3/NERV.nixos.git /mnt/etc/nixos
cd /mnt/etc/nixos

# 3. Edit disko-configuration.nix — replace disk, swap, store, and persist sizes.
nano hosts/disko-configuration.nix

# 4. Provision the disk (THIS WILL ERASE THE TARGET DISK).
nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount hosts/disko-configuration.nix

# 5. Generate hardware configuration and copy it into place.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/hardware-configuration.nix

# 6. Edit hosts/configuration.nix — fill every PLACEHOLDER value.
nano hosts/configuration.nix

# 7. Install.
nixos-install --flake /mnt/etc/nixos#host   # or #server / #vm
```

After the first boot, NERV lives at `/etc/nixos` (the standard NixOS location). Apply future changes with:

```bash
nixos-rebuild switch --flake /etc/nixos#host
# If Home Manager is enabled (nerv.home.enable = true):
nixos-rebuild switch --flake /etc/nixos#host --impure
```

---

### B — BTRFS layout (hostProfile)

> **Before you begin:** find your disk name (`lsblk -d -o NAME,SIZE,MODEL`). NERV uses `modules/system/disko.nix` — the disk layout is configured via `nerv.disko.layout = "btrfs"` in `hostProfile` (already set). Fill `hosts/configuration.nix` with your machine-specific values.

> **Warning:** The step that creates `@root-blank` (step 5 below) is mandatory. The initrd rollback service snapshots `@root-blank → @` on every boot. Skipping step 5 causes first-boot failure: the rollback service exits with an error because `@root-blank` does not exist.

```bash
# 1. Boot the NixOS minimal ISO and get a root shell.

# 2. Clone NERV.nixos into the standard NixOS config location.
mkdir -p /mnt/etc/nixos
git clone https://github.com/atirelli3/NERV.nixos.git /mnt/etc/nixos
cd /mnt/etc/nixos

# 3. Mount the BTRFS install volume temporarily (disko will handle permanent mounts).
#    Nothing to edit in disko.nix — the BTRFS layout is fully declared.
#    Set the disk device in hosts/configuration.nix (step 6).

# 4. Provision the disk (THIS WILL ERASE THE TARGET DISK).
nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount modules/system/disko.nix

# 5. Create the @root-blank rollback baseline — MANDATORY before nixos-install.
#    The initrd rollback service (Phase 10) snapshots @root-blank → @ on every boot.
#    This step creates the clean baseline. Skipping it breaks the first boot.
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank

# 6. Generate hardware configuration and copy it into place.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/hardware-configuration.nix

# 7. Edit hosts/configuration.nix — fill every PLACEHOLDER value.
nano hosts/configuration.nix

# 8. Install.
nixos-install --flake /mnt/etc/nixos#host
```

After the first boot, NERV lives at `/etc/nixos`. Apply future changes with:

```bash
nixos-rebuild switch --flake /etc/nixos#host
# If Home Manager is enabled (nerv.home.enable = true):
nixos-rebuild switch --flake /etc/nixos#host --impure
```

---

### C — Existing NixOS system

```bash
# 1. Back up your current config (optional but recommended).
sudo cp -r /etc/nixos /etc/nixos.bak

# 2. Clone NERV.nixos into /etc/nixos (replaces the standard NixOS config location).
sudo git clone https://github.com/atirelli3/NERV.nixos.git /etc/nixos
cd /etc/nixos

# 3. Copy your existing hardware configuration into place.
sudo cp /etc/nixos.bak/hardware-configuration.nix hosts/hardware-configuration.nix

# 4. Edit hosts/configuration.nix — fill every PLACEHOLDER value.
sudo nano hosts/configuration.nix

# 5. Switch to NERV.
sudo nixos-rebuild switch --flake /etc/nixos#host
```

### D — Enabling Secure Boot (optional, post-install)

Secure Boot is disabled by default (`nerv.secureboot.enable = false`). Enable it after the system is installed and booting correctly. You need a machine with a UEFI firmware that supports Setup Mode.

**Prerequisites:**
- System is installed and boots normally
- UEFI firmware supports Secure Boot Setup Mode

**Step 1 — Enter Setup Mode in UEFI**

Reboot into your UEFI firmware settings and clear all existing Secure Boot keys. This puts the firmware into **Setup Mode**, which allows enrolling new keys. The exact option varies by manufacturer (look for "Secure Boot", "Key Management", "Reset to Setup Mode", or "Clear Secure Boot Keys").

**Step 2 — Enable `nerv.secureboot`**

```bash
# Edit hosts/configuration.nix and set:
nerv.secureboot.enable = true;

# Rebuild and switch.
sudo nixos-rebuild switch --flake /etc/nixos#host
```

**Step 3 — Reboot (Boot 1 of 2)**

On the next boot, the `secureboot-enroll-keys` systemd service automatically:
1. Detects that the firmware is in Setup Mode
2. Runs `sbctl enroll-keys --microsoft` to enroll your keys (Microsoft keys included for hardware compatibility)
3. Writes `/var/lib/secureboot-keys-enrolled` as a sentinel
4. Reboots the machine

**Step 4 — Wait for Boot 2 of 2**

On the following boot, the `secureboot-enroll-tpm2` service automatically:
1. Verifies Secure Boot is now enforcing
2. Binds the LUKS partition to TPM2 PCR 0+7 via `systemd-cryptenroll`
3. Writes `/var/lib/secureboot-setup-done` as a sentinel

From this point, LUKS unlocks automatically on every boot as long as the Secure Boot state is unchanged (PCR 7 tracks the Secure Boot policy).

**Verify the result**

```bash
sbctl status          # should show: Secure Boot enabled, Setup Mode disabled
sbctl verify          # all boot files should be signed
```

**Re-enrollment after a firmware or key change**

If you ever need to re-bind LUKS to TPM2 (e.g. after a firmware update that changes PCR 7):

```bash
luks-cryptenroll      # helper script provided by nerv — re-runs systemd-cryptenroll
```

---

## Configuration

All machine-specific values live in **`hosts/configuration.nix`**. Open it and replace every `PLACEHOLDER`:

```nix
# hosts/configuration.nix

nerv.hostname     = "my-desktop";       # sets networking.hostName
nerv.primaryUser  = [ "alice" ];        # auto-wires wheel + networkmanager groups

nerv.hardware.cpu = "amd";             # "amd" | "intel" | "other"
nerv.hardware.gpu = "nvidia";          # "amd" | "nvidia" | "intel" | "none"

nerv.locale.timeZone      = "Europe/Rome";
nerv.locale.defaultLocale = "en_US.UTF-8";
nerv.locale.keyMap        = "us";

disko.devices.disk.main.device = "/dev/nvme0n1";  # your actual disk

users.users.alice = { isNormalUser = true; };
system.stateVersion = "25.11";
```

Feature toggles and service options are set in the **profile** (`flake.nix`). To override a single option for your machine, add it to `hosts/configuration.nix`:

```nix
# Example overrides inside hosts/configuration.nix

nerv.openssh.port       = 4222;        # change SSH port
nerv.openssh.allowUsers = [ "alice" ]; # restrict SSH to specific users

nerv.impermanence.extraDirs = [ "/var/cache/myapp" ];

# Per-user tmpfs mounts (key = path, value = size)
nerv.impermanence.users.alice = {
  "/home/alice/Downloads" = "8G";
};

# Escape hatch for any hardcoded setting
hardware.nvidia.open = lib.mkForce false;  # Maxwell/Pascal GPUs
```

### Home Manager

NERV wires Home Manager so each user manages their own `~/home.nix`. The system repo does not contain dotfiles.

```nix
# In your profile or hosts/configuration.nix
nerv.home.enable = true;
nerv.home.users  = [ "alice" ];
```

Each listed user must have a `~/home.nix`:

```nix
# ~/home.nix — minimal example
{ pkgs, ... }: {
  home.username    = "alice";
  home.homeDirectory = "/home/alice";

  home.packages = with pkgs; [ git neovim ];
}
```

Rebuild with `--impure` because `~/home.nix` is outside the flake boundary:

```bash
nixos-rebuild switch --flake /etc/nixos#host --impure
```

---

## Module Reference

### `modules/system/`

#### `identity.nix`
Sets hostname, locale, and primary user group membership.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hostname` | `str` | **required** | `networking.hostName` |
| `nerv.locale.timeZone` | `str` | `"UTC"` | `time.timeZone` |
| `nerv.locale.defaultLocale` | `str` | `"en_US.UTF-8"` | `i18n.defaultLocale` |
| `nerv.locale.keyMap` | `str` | `"us"` | `console.keyMap` |
| `nerv.primaryUser` | `[str]` | `[]` | Gets `wheel` + `networkmanager` groups; ZSH shell if `nerv.zsh.enable` |

---

#### `hardware.nix`
CPU microcode, GPU drivers, and hardware-agnostic firmware.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hardware.cpu` | `"amd"│"intel"│"other"` | `"other"` | Enables microcode and IOMMU kernel params |
| `nerv.hardware.gpu` | `"amd"│"nvidia"│"intel"│"none"` | `"none"` | Enables appropriate GPU driver |

Always enables: redistributable firmware, `fwupd` (LVFS firmware updates), weekly SSD TRIM.

> **NVIDIA note:** `hardware.nvidia.open = true` targets Turing+ (RTX 20xx+). For Maxwell/Pascal use `lib.mkForce false`.

---

#### `kernel.nix`
Zen kernel with comprehensive hardening params. Fully opaque — `lib.mkForce` is the escape hatch.

Applies:
- Memory hardening: `slab_nomerge`, `init_on_alloc=1`, `init_on_free=1`, ASLR maximised
- CPU mitigations: PTI (`pti=on`), TSX disabled (`tsx=off`)
- Attack surface reduction: `vsyscall=none`, `debugfs=off`
- Sysctl hardening: network (SYN cookies, RPF, ICMP redirect drop), kernel (`dmesg_restrict`, `kptr_restrict=2`, BPF lockdown, `ptrace_scope=1`)
- Filesystem protections: hardlink/symlink/FIFO guards
- Blacklisted kernel modules: unused filesystems (`cramfs`, `jffs2`, `hfs`, `udf`) and vulnerable protocols (`dccp`, `sctp`, `rds`, `tipc`)

---

#### `security.nix`
System security hardening. Fully opaque — always on.

Includes:
- **AppArmor** — MAC via NixOS module; `killUnconfinedConfinables` opt-in
- **auditd** — syscall audit rules: `execve`, `openat`, `connect`, `setuid/setgid`, writes to `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, `/etc/ssh/sshd_config`
- **ClamAV** — daemon + freshclam updater (24 checks/day)
- **AIDE** — daily file integrity check timer; monitors `/boot`, `/etc`, `/bin`, `/usr`, `/lib`; skips `/nix`
- **lynis** — hardening auditor (`sudo lynis audit system`)

> After first boot, initialise the AIDE database: `sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db`

---

#### `nix.nix`
Nix daemon configuration. Fully opaque.

- `nixpkgs.config.allowUnfree = true`
- Flakes + nix-command enabled
- Daemon access restricted to `@wheel`
- Auto-optimise store (hardlinks) + weekly full optimisation pass
- Weekly GC — deletes generations older than 20 days
- Daily auto-upgrade (no auto-reboot; applies on next manual reboot)

---

#### `boot.nix`
Layout-agnostic initrd and bootloader configuration. Fully opaque — extracted from `hosts/configuration.nix` so the host file stays minimal.

Contains: initrd modules, systemd-boot configuration. Layout-conditional LUKS and initrd services live in `modules/system/disko.nix`.
The `NIXLUKS` label must stay in sync with `modules/system/disko.nix` and `secureboot.nix`.

---

#### `secureboot.nix`
Lanzaboote Secure Boot with automatic TPM2 LUKS bind.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.secureboot.enable` | `bool` | `false` | Enable Lanzaboote + TPM2 auto-unlock |

Setup is fully automated across two boot stages:
- **Boot 1** — detects Setup Mode, enrolls Secure Boot keys via `sbctl`, reboots
- **Boot 2** — binds LUKS to TPM2 PCR 0+7 (PCR 7 now reflects active Secure Boot state)

After that, LUKS unlocks automatically on every boot as long as the Secure Boot state is unchanged.

> Provides `luks-cryptenroll` helper script and `sbctl`/`tpm2-tools` in `systemPackages`.

---

#### `impermanence.nix`
Per-directory tmpfs mounts with an optional full-impermanence server mode.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.impermanence.enable` | `bool` | `false` | Enable impermanence |
| `nerv.impermanence.mode` | `"btrfs"│"full"` | **required** | `btrfs` = BTRFS rollback resets `/` on each boot, state on `/persist` (@persist subvolume); `full` = `/` as tmpfs, state on `/persist` (LVM) |
| `nerv.impermanence.persistPath` | `str` | `"/persist"` | Base path for `environment.persistence` (full mode only) |
| `nerv.impermanence.extraDirs` | `[str]` | `[]` | Additional system paths to mount as tmpfs |
| `nerv.impermanence.users` | `attrs` | `{}` | Per-user paths mapped to size, e.g. `{ alice."/home/alice/Downloads" = "8G"; }` |

BTRFS mode persists (via `environment.persistence`): `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos`, SSH host keys, and `machine-id`. `/var/log` is excluded (persisted by the @log BTRFS subvolume).

Full mode persists: `/var/log`, `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos`, SSH host keys, and `machine-id`.

> Both `btrfs` and `full` modes require `impermanence.nixosModules.impermanence` in the host's modules list (pre-wired in both the `host` and `server` profiles).

---

### `modules/services/`

#### `openssh.nix`
SSH daemon with endlessh tarpit and fail2ban.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.openssh.enable` | `bool` | `false` | Enable SSH |
| `nerv.openssh.port` | `port` | `2222` | SSH listener port (`ssh -p 2222 user@host`) |
| `nerv.openssh.tarpitPort` | `port` | `22` | endlessh tarpit port (wastes bot connections) |
| `nerv.openssh.allowUsers` | `[str]` | `[]` | Restrict SSH to listed users; empty = allow all |
| `nerv.openssh.passwordAuth` | `bool` | `false` | Allow password auth (key-only by default) |
| `nerv.openssh.kbdInteractiveAuth` | `bool` | `false` | Allow keyboard-interactive auth |

fail2ban defaults: 5 global retries, 3 SSH retries in 10 min → 24h ban; exponential growth capped at 168h; LAN subnets always whitelisted.

---

#### `pipewire.nix`
PipeWire audio stack with low-latency defaults.

| Option | Type | Default |
|--------|------|---------|
| `nerv.audio.enable` | `bool` | `false` |

Enables: ALSA (32-bit support), PulseAudio compat, AirPlay sink (RAOP). Low-latency config: 1024/48000 ≈ 21ms quantum. Installs `pwvucontrol` and `helvum`.

---

#### `bluetooth.nix`
Bluetooth with OBEX file transfer.

| Option | Type | Default |
|--------|------|---------|
| `nerv.bluetooth.enable` | `bool` | `false` |

---

#### `printing.nix`
CUPS printing with Avahi network discovery.

| Option | Type | Default |
|--------|------|---------|
| `nerv.printing.enable` | `bool` | `false` |

Owns `avahi.enable = true` independently of `nerv.audio`.

---

#### `zsh.nix`
ZSH as default shell with plugins.

| Option | Type | Default |
|--------|------|---------|
| `nerv.zsh.enable` | `bool` | `false` |

Plugins loaded in fixed order: autosuggestions → syntax-highlighting → history-substring-search (order matters; manual sourcing enforces it).

---

## Escape Hatch

Any hardcoded setting can be overridden at the host level with `lib.mkForce`:

```nix
# hosts/configuration.nix
{ lib, ... }: {
  # Example: use the hardened kernel instead of Zen
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_hardened;

  # Example: old NVIDIA GPU (Maxwell/Pascal)
  hardware.nvidia.open = lib.mkForce false;
}
```

---

## Repository Layout

```
nerv.nixos/
├── flake.nix                    # inputs, profiles (host/server), nixosModules, nixosConfigurations
├── hosts/
│   ├── configuration.nix        # machine identity — edit this
│   └── hardware-configuration.nix  # replace with nixos-generate-config output
├── modules/
│   ├── default.nix              # aggregates system + services + home
│   ├── system/
│   │   ├── identity.nix         # hostname, locale, primaryUser
│   │   ├── hardware.nix         # cpu/gpu enum options
│   │   ├── kernel.nix           # Zen kernel + hardening params
│   │   ├── security.nix         # AppArmor, auditd, ClamAV, AIDE
│   │   ├── nix.nix              # daemon, GC, optimise, autoUpgrade
│   │   ├── boot.nix             # layout-agnostic initrd + bootloader
│   │   ├── secureboot.nix       # Lanzaboote + TPM2
│   │   ├── disko.nix            # disk layout (btrfs/lvm), LUKS, initrd services
│   │   └── impermanence.nix     # BTRFS or full impermanence mode
│   └── services/
│       ├── openssh.nix          # SSH + endlessh + fail2ban
│       ├── pipewire.nix         # audio stack
│       ├── bluetooth.nix        # BT + OBEX
│       ├── printing.nix         # CUPS + Avahi
│       └── zsh.nix              # ZSH + plugins
└── home/
    └── default.nix              # Home Manager NixOS wiring
```
