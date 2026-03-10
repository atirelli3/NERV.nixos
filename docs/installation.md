# Installation Guide

This guide covers all installation scenarios for NERV.nixos.

---

## Before you begin

**Requirements:**
- x86_64 machine with UEFI firmware
- A target disk (all data will be erased)
- Network access during install

**Choose your disk layout:**

| Layout | Profile | Use case |
|--------|---------|----------|
| `btrfs` | `host` | Desktop/laptop — BTRFS rollback resets `/` on every boot |
| `lvm` | `server` | Headless server — `/` as tmpfs, state on `/persist` LVM volume |

---

## Scenario A — New system (LVM layout)

For servers or desktops where BTRFS impermanence is not needed.

```bash
# 1. Boot the NixOS minimal ISO and get a root shell.

# 2. Clone NERV.nixos.
mkdir -p /mnt/etc/nixos
git clone https://github.com/atirelli3/NERV.nixos.git /mnt/etc/nixos
cd /mnt/etc/nixos

# 3. Find your disk name.
lsblk -d -o NAME,SIZE,MODEL

# 4. Edit hosts/configuration.nix — set nerv.disko.layout = "lvm" and fill LVM sizes.
nano hosts/configuration.nix

# 5. Provision the disk (THIS WILL ERASE THE TARGET DISK).
nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount hosts/disko-configuration.nix

# 6. Generate hardware configuration.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/hardware-configuration.nix

# 7. Install.
nixos-install --flake /mnt/etc/nixos#server
```

---

## Scenario B — New system (BTRFS layout)

For desktops/laptops with BTRFS rollback impermanence.

> **Critical — do not skip step 5.** The initrd rollback service snapshots `@root-blank → @` on every boot to reset `/`. If `@root-blank` does not exist, the rollback service exits 1 and the system fails to mount `/` on first boot.

```bash
# 1. Boot the NixOS minimal ISO and get a root shell.

# 2. Clone NERV.nixos.
mkdir -p /mnt/etc/nixos
git clone https://github.com/atirelli3/NERV.nixos.git /mnt/etc/nixos
cd /mnt/etc/nixos

# 3. Find your disk name.
lsblk -d -o NAME,SIZE,MODEL

# 4. Edit hosts/configuration.nix — set disko.devices.disk.main.device to your disk.
nano hosts/configuration.nix

# 5. Provision the disk (THIS WILL ERASE THE TARGET DISK).
nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount modules/system/disko.nix

# 6. Create the rollback baseline — MANDATORY.
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank

# 7. Generate hardware configuration.
nixos-generate-config --no-filesystems --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix hosts/hardware-configuration.nix

# 8. Edit hosts/configuration.nix — fill every PLACEHOLDER value.
nano hosts/configuration.nix

# 9. Install.
nixos-install --flake /mnt/etc/nixos#host
```

---

## Scenario C — Existing NixOS system

Add NERV to a running NixOS system without reinstalling.

```bash
# 1. Back up your current config.
sudo cp -r /etc/nixos /etc/nixos.bak

# 2. Clone NERV.nixos.
sudo git clone https://github.com/atirelli3/NERV.nixos.git /etc/nixos
cd /etc/nixos

# 3. Copy your existing hardware configuration.
sudo cp /etc/nixos.bak/hardware-configuration.nix hosts/hardware-configuration.nix

# 4. Edit hosts/configuration.nix — fill every PLACEHOLDER value.
sudo nano hosts/configuration.nix

# 5. Switch to NERV.
sudo nixos-rebuild switch --flake /etc/nixos#host
```

> Note: NERV enables AppArmor, auditd, ClamAV, and kernel hardening on first switch. If your existing config conflicts with any of these, use `lib.mkForce` in `hosts/configuration.nix` to override.

---

## Scenario D — Enabling Secure Boot (post-install)

Secure Boot (`nerv.secureboot.enable`) is disabled by default. Enable it after the system is installed and booting correctly.

**Prerequisites:**
- System is installed and boots normally
- UEFI firmware supports Secure Boot Setup Mode

### Step 1 — Enter Setup Mode in UEFI

Reboot into your UEFI firmware settings and clear all existing Secure Boot keys. The exact option varies by manufacturer (look for "Secure Boot", "Key Management", "Reset to Setup Mode", or "Clear Secure Boot Keys").

### Step 2 — Enable Secure Boot

```nix
# hosts/configuration.nix
nerv.secureboot.enable = true;
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos#host
```

### Step 3 — Boot 1 of 2

On the next boot, `secureboot-enroll-keys.service` automatically:
1. Detects that the firmware is in Setup Mode
2. Runs `sbctl enroll-keys --microsoft`
3. Writes `/var/lib/secureboot-keys-enrolled` as a sentinel
4. Reboots the machine

### Step 4 — Boot 2 of 2

On the following boot, `secureboot-enroll-tpm2.service` automatically:
1. Verifies Secure Boot is now enforcing
2. Binds LUKS to TPM2 PCR 0+7 via `systemd-cryptenroll`
3. Writes `/var/lib/secureboot-setup-done` as a sentinel

From this point, LUKS unlocks automatically on every boot as long as the Secure Boot state is unchanged.

### Verify

```bash
sbctl status   # Secure Boot: enabled, Setup Mode: disabled
sbctl verify   # all boot files should be signed
```

### Re-enrollment after a firmware or key change

```bash
luks-cryptenroll   # helper script provided by NERV — re-runs systemd-cryptenroll
```

> Only run `luks-cryptenroll` after verifying `sbctl status` shows Secure Boot enabled. Running it on a system without Secure Boot will wipe the TPM2 slot and require manual LUKS password entry on next boot.

---

## Applying changes after install

```bash
# Standard rebuild
sudo nixos-rebuild switch --flake /etc/nixos#host

# With Home Manager (required when nerv.home.enable = true)
sudo nixos-rebuild switch --flake /etc/nixos#host --impure

# Test a new configuration without activating (dry-run)
sudo nixos-rebuild dry-build --flake /etc/nixos#host

# Update all flake inputs
sudo nix flake update /etc/nixos
```

---

## Post-install checklist

After first boot, run these one-time setup steps:

```bash
# 1. Initialize the AIDE file integrity database (required once after install).
sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 2. Verify Secure Boot status (if enabled).
sbctl status

# 3. Run a hardening audit.
sudo lynis audit system

# 4. Check ClamAV virus definitions are up to date.
sudo freshclam
```

---

## Troubleshooting

**`nix flake check` fails with type errors:**
Replace all `PLACEHOLDER` strings in `hosts/configuration.nix`. The `nerv.hardware.cpu` and `nerv.hardware.gpu` options use enum types that reject `"PLACEHOLDER"` at evaluation time.

**First boot fails — cannot mount `/`:**
If using BTRFS layout, the `@root-blank` subvolume may be missing. Boot from the live ISO, mount the BTRFS volume, and create the snapshot:
```bash
mount /dev/mapper/cryptroot /mnt
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
```

**SSH fingerprint mismatch after reboot:**
This can occur if `/persist` failed to mount before sshd started. The bind-mount failure should cause a boot failure (fail-closed), but if it doesn't, verify that `fileSystems."/persist".neededForBoot = true` is set and that the LUKS device is unlocking before the filesystem mount.

**Home Manager build fails with "file not found":**
Every user listed in `nerv.home.users` must have a `~/home.nix` on the target machine before running `nixos-rebuild`. Ensure the file exists at `/home/<username>/home.nix`.
