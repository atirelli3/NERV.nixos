# Configuration Reference

All `nerv.*` options in one place. Machine-specific values live in `hosts/configuration.nix`; feature toggles and defaults live in the profile attrset inside `flake.nix`.

---

## Required options (no defaults)

These must be set explicitly in `hosts/configuration.nix` — the system will not build without them.

| Option | Type | Description |
|--------|------|-------------|
| `nerv.hostname` | `str` | Machine hostname. Must not be empty. |
| `nerv.hardware.cpu` | `"amd" \| "intel" \| "other"` | CPU vendor for microcode selection. |
| `nerv.hardware.gpu` | `"amd" \| "nvidia" \| "intel" \| "none"` | GPU vendor for driver selection. |
| `nerv.locale.timeZone` | `str` | IANA timezone (e.g. `"Europe/Rome"`). |
| `nerv.locale.defaultLocale` | `str` | Locale string (e.g. `"en_US.UTF-8"`). |
| `nerv.locale.keyMap` | `str` | Console keymap (e.g. `"us"`). |
| `nerv.disko.layout` | `"btrfs" \| "lvm"` | Disk layout. Drives impermanence mode. |
| `disko.devices.disk.main.device` | `str` | Target disk path (e.g. `"/dev/nvme0n1"`). |
| `system.stateVersion` | `str` | NixOS state version (e.g. `"25.11"`). |

**LVM-only** (required when `nerv.disko.layout = "lvm"`):

| Option | Type | Description |
|--------|------|-------------|
| `nerv.disko.lvm.swapSize` | `str` | Swap LV size (e.g. `"8G"`). |
| `nerv.disko.lvm.storeSize` | `str` | `/nix` store LV size (e.g. `"64G"`). |
| `nerv.disko.lvm.persistSize` | `str` | `/persist` LV size (e.g. `"32G"`). |

---

## System options

### Identity — `modules/system/identity.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hostname` | `str` | required | Sets `networking.hostName`. |
| `nerv.primaryUser` | `[str]` | `[]` | Auto-wires `wheel` + `networkmanager` groups; sets ZSH shell if `nerv.zsh.enable`. |
| `nerv.locale.timeZone` | `str` | `"UTC"` | `time.timeZone`. |
| `nerv.locale.defaultLocale` | `str` | `"en_US.UTF-8"` | `i18n.defaultLocale`. |
| `nerv.locale.keyMap` | `str` | `"us"` | `console.keyMap`. |

### Hardware — `modules/system/hardware.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hardware.cpu` | `"amd" \| "intel" \| "other"` | `"other"` | Enables CPU microcode and IOMMU params. |
| `nerv.hardware.gpu` | `"amd" \| "nvidia" \| "intel" \| "none"` | `"none"` | Enables GPU driver. NVIDIA targets Turing+ (RTX 20xx+); use `lib.mkForce false` for Maxwell/Pascal. |

Always enabled regardless of CPU/GPU choice: `hardware.enableAllFirmware`, `services.fwupd`, `services.fstrim` (weekly TRIM).

### Disk layout — `modules/system/disko.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.disko.layout` | `"btrfs" \| "lvm"` | required | Disk layout to provision. |
| `nerv.disko.lvm.swapSize` | `str` | required (LVM) | Swap LV size. |
| `nerv.disko.lvm.storeSize` | `str` | required (LVM) | `/nix` store LV size. |
| `nerv.disko.lvm.persistSize` | `str` | required (LVM) | `/persist` LV size. |

### Impermanence — `modules/system/impermanence.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.impermanence.enable` | `bool` | `false` | Enable impermanence. |
| `nerv.impermanence.mode` | `"btrfs" \| "full"` | required | `btrfs` = BTRFS rollback; `full` = tmpfs root. |
| `nerv.impermanence.persistPath` | `str` | `"/persist"` | Base path for `environment.persistence` (full mode only). |
| `nerv.impermanence.extraDirs` | `[str]` | `[]` | Additional system paths to mount as tmpfs. |
| `nerv.impermanence.users` | `attrs` | `{}` | Per-user paths mapped to size. Example: `{ alice."/home/alice/Downloads" = "8G"; }` |

### Secure Boot — `modules/system/secureboot.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.secureboot.enable` | `bool` | `false` | Enable Lanzaboote + TPM2 auto-unlock. Requires two-boot setup sequence. |

---

## Service options

### OpenSSH — `modules/services/openssh.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.openssh.enable` | `bool` | `false` | Enable SSH daemon. |
| `nerv.openssh.port` | `port` | `2222` | SSH listener port. |
| `nerv.openssh.tarpitPort` | `port` | `22` | endlessh tarpit port (wastes bot connections). Must differ from `port`. |
| `nerv.openssh.allowUsers` | `[str]` | `[]` | Restrict SSH to listed users; empty = allow all authenticated users. |
| `nerv.openssh.passwordAuth` | `bool` | `false` | Allow password authentication (key-only by default). |
| `nerv.openssh.kbdInteractiveAuth` | `bool` | `false` | Allow keyboard-interactive authentication. |

### Audio — `modules/services/pipewire.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.audio.enable` | `bool` | `false` | Enable PipeWire audio stack. |

### Bluetooth — `modules/services/bluetooth.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.bluetooth.enable` | `bool` | `false` | Enable Bluetooth with OBEX file transfer. |

### Printing — `modules/services/printing.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.printing.enable` | `bool` | `false` | Enable CUPS printing with Avahi network discovery. |

### ZSH — `modules/services/zsh.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.zsh.enable` | `bool` | `true` | Enable ZSH as system shell with plugins. |

### Home Manager — `home/default.nix`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.home.enable` | `bool` | `false` | Enable Home Manager NixOS integration. |
| `nerv.home.users` | `[str]` | `[]` | Users to wire. Each must have `~/home.nix`. Requires `--impure` on rebuild. |

---

## Opaque modules (no options)

These modules apply unconditionally when imported and have no user-facing toggles. Use `lib.mkForce` to override specific settings.

| Module | Always enables |
|--------|---------------|
| `modules/system/kernel.nix` | Zen kernel, sysctl hardening, module blacklist |
| `modules/system/security.nix` | AppArmor, auditd, ClamAV, AIDE, sudo restrictions |
| `modules/system/nix.nix` | Flakes, GC, store optimisation, auto-upgrade |
| `modules/system/boot.nix` | systemd-boot, EFI, systemd initrd |
| `modules/system/packages.nix` | `git`, `fastfetch` |

---

## Example: minimal host configuration

```nix
# hosts/configuration.nix
{ ... }: {
  nerv.hostname    = "my-laptop";
  nerv.primaryUser = [ "alice" ];

  nerv.hardware.cpu = "amd";
  nerv.hardware.gpu = "amd";

  nerv.locale.timeZone      = "Europe/Rome";
  nerv.locale.defaultLocale = "en_US.UTF-8";
  nerv.locale.keyMap        = "it";

  nerv.disko.layout = "btrfs";

  nerv.impermanence.enable = true;
  nerv.impermanence.mode   = "btrfs";

  nerv.openssh.enable  = true;
  nerv.audio.enable    = true;
  nerv.bluetooth.enable = true;

  nerv.home.enable = true;
  nerv.home.users  = [ "alice" ];

  disko.devices.disk.main.device = "/dev/nvme0n1";

  users.users.alice = { isNormalUser = true; };
  system.stateVersion = "25.11";
}
```

## Example: server configuration

```nix
# hosts/configuration.nix
{ ... }: {
  nerv.hostname    = "my-server";
  nerv.primaryUser = [ "ops" ];

  nerv.hardware.cpu = "intel";
  nerv.hardware.gpu = "none";

  nerv.locale.timeZone      = "UTC";
  nerv.locale.defaultLocale = "en_US.UTF-8";
  nerv.locale.keyMap        = "us";

  nerv.disko.layout          = "lvm";
  nerv.disko.lvm.swapSize    = "8G";
  nerv.disko.lvm.storeSize   = "64G";
  nerv.disko.lvm.persistSize = "32G";

  nerv.impermanence.enable = true;
  nerv.impermanence.mode   = "full";

  nerv.openssh.enable     = true;
  nerv.openssh.allowUsers = [ "ops" ];

  disko.devices.disk.main.device = "/dev/sda";

  users.users.ops = { isNormalUser = true; };
  system.stateVersion = "25.11";
}
```
