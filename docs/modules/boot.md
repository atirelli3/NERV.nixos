# Module: Boot

**File:** `modules/system/boot.nix`

Layout-agnostic initrd and bootloader configuration. Fully opaque — always active.

LUKS and layout-conditional initrd services live in `modules/system/disko.nix`, not here.

---

## What it configures

### Bootloader

- `boot.loader.systemd-boot.enable = true` — EFI system partition bootloader
- `boot.loader.efi.canTouchEfiVariables = true`
- `boot.loader.systemd-boot.configurationLimit = 5` — keeps last 5 generations in the boot menu

> If `nerv.secureboot.enable = true`, `secureboot.nix` overrides `systemd-boot.enable = lib.mkForce false` and replaces it with Lanzaboote.

### initrd

- `boot.initrd.systemd.enable = true` — uses systemd as the initrd init (required for impermanence rollback services and TPM2 unlocking)

### initrd modules

Common modules loaded unconditionally:

| Module | Purpose |
|--------|---------|
| `btrfs` | BTRFS support |
| `xhci_pci` | USB 3.0 (xHCI) |
| `ahci` | SATA |
| `nvme` | NVMe storage |
| `sd_mod` | SCSI disk |
| `dm-snapshot` | Device Mapper snapshots |

---

## Override examples

```nix
# hosts/configuration.nix
{ lib, ... }: {
  # Keep more boot generations
  boot.loader.systemd-boot.configurationLimit = lib.mkForce 10;

  # Add hardware-specific initrd modules
  boot.initrd.availableKernelModules = [ "virtio_blk" "virtio_pci" ];
}
```

---

## Notes

- The `NIXLUKS` LUKS label used by the boot unlock configuration must stay in sync between `modules/system/disko.nix` and `modules/system/secureboot.nix`
- `boot.initrd.systemd.enable = true` is a hard requirement for the BTRFS rollback service in `disko.nix` and for TPM2-based LUKS unlock in `secureboot.nix`
