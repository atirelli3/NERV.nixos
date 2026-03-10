# Module: Disko (Disk Layout)

**File:** `modules/system/disko.nix`

Declarative disk partitioning via [Disko](https://github.com/nix-community/disko). Supports two layouts: BTRFS (desktop) and LVM (server).

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.disko.layout` | `"btrfs" \| "lvm"` | required | Disk layout to provision. |
| `nerv.disko.lvm.swapSize` | `str` | required (LVM) | Swap LV size (e.g. `"8G"`). |
| `nerv.disko.lvm.storeSize` | `str` | required (LVM) | `/nix` store LV size (e.g. `"64G"`). |
| `nerv.disko.lvm.persistSize` | `str` | required (LVM) | `/persist` LV size (e.g. `"32G"`). |

The target disk is set via `disko.devices.disk.main.device` (a standard Disko option):
```nix
disko.devices.disk.main.device = "/dev/nvme0n1";
```

---

## BTRFS layout

Used with `nerv.disko.layout = "btrfs"`. Designed for desktop/laptop with BTRFS impermanence.

```
/dev/nvme0n1 (GPT)
├── /dev/nvme0n1p1  1G  FAT32   /boot     label: NIXBOOT
└── /dev/nvme0n1p2  *   LUKS    cryptroot  label: NIXLUKS
    └── BTRFS                              label: NIXBTRFS
        ├── @           /              (compress=zstd:3, noatime)
        ├── @root-blank (rollback baseline — created manually during install)
        ├── @home       /home          (compress=zstd:3, noatime)
        ├── @nix        /nix           (compress=zstd:3, noatime)
        ├── @persist    /persist       (compress=zstd:3, noatime)
        └── @log        /var/log       (compress=zstd:3, noatime)
```

**Mount options applied to all subvolumes:** `compress=zstd:3`, `noatime`, `space_cache=v2`

**LUKS settings:** `allowDiscards = true` (enables TRIM pass-through to SSD)

### Rollback service

At every boot, a systemd initrd service resets `/` to the `@root-blank` baseline:

```bash
# Simplified rollback logic (runs in initrd)
mount -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp
btrfs subvolume delete /btrfs_tmp/@  || true
btrfs subvolume snapshot -r /btrfs_tmp/@root-blank /btrfs_tmp/@
umount /btrfs_tmp
```

This means `/` is always fresh on boot. Persistent data must be stored in `/persist` and wired via `environment.persistence` (see [Impermanence](impermanence.md)).

> **`@root-blank` must be created during installation.** See [Installation Guide — Scenario B](../installation.md#scenario-b--new-system-btrfs-layout).

---

## LVM layout

Used with `nerv.disko.layout = "lvm"`. Designed for servers with full impermanence (tmpfs root).

```
/dev/sda (GPT)
├── /dev/sda1  1G   FAT32   /boot     label: NIXBOOT
└── /dev/sda2  *    LUKS    cryptroot  label: NIXLUKS
    └── LVM PV → VG: lvmroot
        ├── swap     swap              label: NIXSWAP
        ├── store    ext4    /nix      label: NIXSTORE
        └── persist  ext4    /persist  label: NIXPERSIST
```

LV sizes are configured via `nerv.disko.lvm.*` options.

---

## Disk labels

All labels are uppercase and used by other modules for device references:

| Label | Device | Used by |
|-------|--------|---------|
| `NIXBOOT` | EFI partition | bootloader |
| `NIXLUKS` | LUKS container | `boot.nix`, `secureboot.nix` |
| `NIXBTRFS` | BTRFS volume | `impermanence.nix` |
| `NIXSWAP` | Swap LV | kernel swap |
| `NIXSTORE` | Nix store LV | Nix daemon |
| `NIXPERSIST` | Persist LV | `impermanence.nix` |

> These labels must stay in sync with any references in `boot.nix` and `secureboot.nix`.

---

## Provisioning

Run Disko during installation to partition and format the disk:

```bash
# BTRFS layout — uses modules/system/disko.nix
nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount modules/system/disko.nix

# LVM layout — uses hosts/disko-configuration.nix
nix --experimental-features "nix-community/disko/v1.13.0" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount hosts/disko-configuration.nix
```

> `destroy,format,mount` erases the entire target disk. Double-check `disko.devices.disk.main.device` before running.
