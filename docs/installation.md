# Installation Guide

This guide covers all installation scenarios for NERV.nixos — from live ISO to first boot.

---

## Before you begin

**Requirements:**
- x86_64 machine with UEFI firmware
- A target disk (all data will be erased)
- Network access during install

**Choose your profile:**

| Profile | Layout | Use case |
|---------|--------|----------|
| `host` | `btrfs` | Desktop/laptop — BTRFS rollback resets `/` on every boot |
| `server` | `lvm` | Headless server — `/` as tmpfs, state on `/persist` LVM volume |

---

## Scenario A — New system (BTRFS layout, `host` profile)

For desktops and laptops. BTRFS impermanence rolls `/` back to a blank snapshot on every boot.
Persistent state lives on dedicated subvolumes: `/home`, `/nix`, `/persist`, `/var/log`.

> **Why clone to `/tmp` first?** disko erases and remounts `/mnt`. Any clone placed in `/mnt`
> before disko runs will be wiped. Clone to the live-ISO ramdisk, configure, provision the
> disk, then copy the repo to the freshly mounted target filesystem.

```bash
# 1. Boot the NixOS minimal ISO and get a shell.

# 2. Find your target disk.
lsblk -d -o NAME,SIZE,MODEL

# 3. Clone NERV to the live-ISO ramdisk (NOT /mnt — disko will wipe /mnt).
git clone https://github.com/atirelli3/NERV.nixos.git /tmp/nixos

# 4. Fill every value in the host config.
nano /tmp/nixos/hosts/configuration.nix
#   nerv.hostname, nerv.primaryUser
#   nerv.hardware.cpu / gpu
#   nerv.locale.*
#   disko.devices.disk.main.device  (e.g. "/dev/nvme0n1")
#   nerv.disko.layout = "btrfs"

# 5. (Optional) Enable Secure Boot now rather than post-install.
#    If you prefer to enable it later, skip this step and see Scenario D.
nano /tmp/nixos/flake.nix
#   nerv.secureboot.enable = true;

# 6. Set the LUKS encryption password.
#    disko reads /tmp/luks-password during formatting to set the passphrase.
echo -n "your-luks-password" > /tmp/luks-password

# 7. Provision the disk — THIS ERASES ALL DATA ON THE TARGET DISK.
#    Must run as root (sudo) — disko needs raw disk access.
sudo nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount --flake /tmp/nixos#host

# 8. Verify partitions and subvolumes.
#    Expected: ESP (NIXBOOT), LUKS (NIXLUKS) → cryptroot (NIXBTRFS) → subvolumes at /mnt
lsblk -o NAME,LABEL,SIZE,TYPE,MOUNTPOINTS
#    Expected subvolumes: @  @home  @nix  @persist  @log  @root-blank  (all created by disko)
btrfs subvolume list /mnt

# 9. Copy the configured repo to the target filesystem.
#    cp -r preserves all edits and .git metadata; no re-clone needed.
sudo mkdir -p /mnt/etc
sudo cp -r /tmp/nixos /mnt/etc/nixos

# 10. Generate hardware configuration directly into the right location.
#     --show-hardware-config prints to stdout, avoiding any overwrite of the repo.
sudo nixos-generate-config --no-filesystems --show-hardware-config \
  | sudo tee /mnt/etc/nixos/hosts/hardware-configuration.nix

# 11. If Secure Boot was enabled in step 5 — create sbctl keys now.
#     The Lanzaboote bootloader installer (run by nixos-install) looks for keys in two places:
#       /var/lib/sbctl           — host path (where lanzaboote runs during nixos-install)
#       /mnt/var/lib/sbctl       — chroot path (used by nixos-enter inside nixos-install)
#     /mnt/persist/var/lib/sbctl — impermanence restores these on every boot after rollback
#     All three must be populated before running nixos-install.
nix-shell -p sbctl --run "sudo sbctl create-keys"
sudo mkdir -p /mnt/var/lib/sbctl /mnt/persist/var/lib/sbctl
sudo cp -r /var/lib/sbctl/. /mnt/var/lib/sbctl/
sudo cp -r /var/lib/sbctl/. /mnt/persist/var/lib/sbctl/

# 12. Stage all files.
#     nix flakes only evaluate git-tracked/staged files; unstaged edits are invisible to nix.
sudo git -C /mnt/etc/nixos add -A

# 13. Install.
#     nixos-install will prompt for a root password at the end.
sudo nixos-install --flake /mnt/etc/nixos#host

# 14. Set your user password (nixos-install only prompts for root).
sudo nixos-enter --root /mnt
passwd demon0   # replace with your username
exit

# 15. Copy the config to /persist so it survives the first BTRFS rollback.
#     On first boot, impermanence bind-mounts /persist/etc/nixos → /etc/nixos.
sudo cp -rT /mnt/etc/nixos /mnt/persist/etc/nixos

# 16. Reboot and remove the ISO.
sudo reboot
```

**First boot sequence:**
1. initrd opens LUKS (enter the password set in step 6)
2. initrd rollback service replaces `@` with `@root-blank` (blank root)
3. Stage 2 activates: impermanence bind-mounts `/persist/...` → `/var/lib`, `/etc/nixos`, `/etc/ssh`
4. System is ready

**If Secure Boot was enabled — first boot requires UEFI Setup Mode:**

Before rebooting, enter UEFI firmware and **clear all existing Secure Boot keys** to enter Setup Mode.
Then boot normally. The automated two-boot process takes over:

- **Boot 1:** `secureboot-enroll-keys.service` detects Setup Mode → runs `sbctl enroll-keys --microsoft` → reboots automatically
- **Boot 2:** `secureboot-enroll-tpm2.service` verifies Secure Boot is enforcing → binds LUKS to TPM2 (PCR 0+7)

From Boot 2 onward, LUKS unlocks automatically without a password prompt.

**Future rebuilds:**
```bash
sudo nixos-rebuild switch --flake /etc/nixos#host
```

---

## Scenario B — New system (LVM layout, `server` profile)

For headless servers. `/` is a tmpfs that resets on every reboot.
Persistent state lives on LVM volumes: `/nix` (store), `/persist` (state).

```bash
# 1. Boot the NixOS minimal ISO and get a shell.

# 2. Find your target disk.
lsblk -d -o NAME,SIZE,MODEL

# 3. Clone NERV to the live-ISO ramdisk (NOT /mnt).
git clone https://github.com/atirelli3/NERV.nixos.git /tmp/nixos

# 4. Fill every value in the host config.
nano /tmp/nixos/hosts/configuration.nix
#   nerv.hostname, nerv.primaryUser
#   nerv.hardware.cpu / gpu
#   nerv.locale.*
#   disko.devices.disk.main.device  (e.g. "/dev/sda")
#   nerv.disko.layout = "lvm"
#   nerv.disko.lvm.swapSize    (e.g. "16G" — 2× RAM; check with: free -h)
#   nerv.disko.lvm.storeSize   (e.g. "60G" — /nix ext4)
#   nerv.disko.lvm.persistSize (e.g. "20G" — /persist ext4)

# 5. Set the LUKS encryption password.
echo -n "your-luks-password" > /tmp/luks-password

# 6. Provision the disk — THIS ERASES ALL DATA ON THE TARGET DISK.
sudo nix --experimental-features "nix-command flakes" \
  run github:nix-community/disko/v1.13.0 -- \
  --mode destroy,format,mount --flake /tmp/nixos#server

# 7. Copy the repo to the target filesystem.
sudo mkdir -p /mnt/etc
sudo cp -r /tmp/nixos /mnt/etc/nixos

# 8. Generate hardware configuration.
sudo nixos-generate-config --no-filesystems --show-hardware-config \
  | sudo tee /mnt/etc/nixos/hosts/hardware-configuration.nix

# 9. Stage all files.
sudo git -C /mnt/etc/nixos add -A

# 10. Install.
sudo nixos-install --flake /mnt/etc/nixos#server

# 11. Set your user password.
sudo nixos-enter --root /mnt
passwd <username>
exit

# 12. Copy config to /persist.
sudo cp -rT /mnt/etc/nixos /mnt/persist/etc/nixos

# 13. Reboot and remove the ISO.
sudo reboot
```

---

## Scenario C — Existing NixOS system

Add NERV to a running NixOS system without reinstalling.

```bash
# 1. Back up your current config.
sudo cp -r /etc/nixos /etc/nixos.bak

# 2. Clone NERV.
sudo git clone https://github.com/atirelli3/NERV.nixos.git /etc/nixos

# 3. Copy your existing hardware configuration.
sudo cp /etc/nixos.bak/hardware-configuration.nix /etc/nixos/hosts/hardware-configuration.nix

# 4. Fill every value in the host config.
sudo nano /etc/nixos/hosts/configuration.nix

# 5. Switch to NERV.
sudo nixos-rebuild switch --flake /etc/nixos#host
```

> Note: NERV enables AppArmor, auditd, ClamAV, and kernel hardening on first switch.
> If your existing config conflicts with any of these, use `lib.mkForce` in `hosts/configuration.nix` to override.

---

## Scenario D — Enabling Secure Boot (post-install)

If you did not enable Secure Boot during installation (Scenario A step 5), enable it from the
running system after confirming the system boots correctly.

**Prerequisites:**
- System is installed and boots normally
- UEFI firmware supports Secure Boot Setup Mode

### Step 1 — Create sbctl keys (if not done during install)

```bash
sudo sbctl create-keys
```

### Step 2 — Enable Secure Boot

```nix
# hosts/configuration.nix  (or flake.nix host block)
nerv.secureboot.enable = true;
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos#host
```

### Step 3 — Enter UEFI Setup Mode

Reboot into UEFI firmware settings and clear all existing Secure Boot keys.
(Look for "Secure Boot", "Key Management", "Reset to Setup Mode", or "Clear Secure Boot Keys".)

### Step 4 — Boot 1 of 2

On the next boot, `secureboot-enroll-keys.service` automatically:
1. Detects Setup Mode
2. Runs `sbctl enroll-keys --microsoft`
3. Reboots the machine

### Step 5 — Boot 2 of 2

On the following boot, `secureboot-enroll-tpm2.service` automatically:
1. Verifies Secure Boot is enforcing
2. Binds LUKS to TPM2 PCR 0+7 via `systemd-cryptenroll`

From this point, LUKS unlocks automatically on every boot.

### Verify

```bash
sbctl status   # Secure Boot: enabled, Setup Mode: disabled
sbctl verify   # all boot files should be signed
```

### Re-enrollment after a firmware or key change

```bash
luks-cryptenroll   # NERV helper — re-runs systemd-cryptenroll
```

> Only run `luks-cryptenroll` after verifying `sbctl status` shows Secure Boot enabled.

---

## Applying changes after install

```bash
# Standard rebuild
sudo nixos-rebuild switch --flake /etc/nixos#host

# With Home Manager (required when nerv.home.enable = true)
sudo nixos-rebuild switch --flake /etc/nixos#host --impure

# Test without activating
sudo nixos-rebuild dry-build --flake /etc/nixos#host

# Update all flake inputs
sudo nix flake update /etc/nixos
```

---

## Post-install checklist

```bash
# 1. Initialize the AIDE file integrity database (required once after install).
sudo aide --init && sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 2. Verify Secure Boot status (if enabled).
sbctl status

# 3. Check ClamAV virus definitions are up to date.
sudo freshclam
```

---

## Troubleshooting

**`error: function 'anonymous lambda' called without required argument 'pkgs'` during disko:**
You passed the module file path directly to disko (`modules/system/disko.nix`). That file is a
NixOS module and cannot be evaluated standalone. Use `--flake /tmp/nixos#host` instead.

**disko fails with permission denied:**
Run disko with `sudo` — it needs raw disk access.

**`nix flake check` fails with type errors:**
Replace all `PLACEHOLDER` strings in `hosts/configuration.nix`. The `nerv.hardware.cpu` and
`nerv.hardware.gpu` options use enum types that reject `"PLACEHOLDER"` at evaluation time.

**`error: path '//mnt/etc/nixos' does not exist` with `path:` URI:**
Use `--flake /mnt/etc/nixos#host` (plain path) instead of `--flake path:/mnt/etc/nixos#host`.
The `path:` URI scheme causes a double-slash bug in this nix version.

**nix cannot see edited files (changes to `hosts/configuration.nix` are ignored):**
nix flakes only evaluate git-tracked and staged files. Run `sudo git -C /mnt/etc/nixos add -A`
before every `nixos-install` attempt.

**`nixos-generate-config --root /mnt` wiped the repo:**
`nixos-generate-config --root /mnt` writes files to `/mnt/etc/nixos/`, overwriting the repo.
Always use `--show-hardware-config` and pipe to the destination:
```bash
sudo nixos-generate-config --no-filesystems --show-hardware-config \
  | sudo tee /mnt/etc/nixos/hosts/hardware-configuration.nix
```

**`Failed to read public key from /var/lib/sbctl/keys/db/db.pem` during nixos-install:**
The Lanzaboote bootloader installer runs inside a chroot (`nixos-enter`) during `nixos-install`,
so it looks for sbctl keys at `/mnt/var/lib/sbctl` (not `/var/lib/sbctl` on the live ISO).
The keys must exist in all three locations before running `nixos-install`:
```bash
# Create keys on live ISO
nix-shell -p sbctl --run "sudo sbctl create-keys"
# Copy to chroot path (for nixos-install)
sudo mkdir -p /mnt/var/lib/sbctl
sudo cp -r /var/lib/sbctl/. /mnt/var/lib/sbctl/
# Copy to persist (for impermanence after first boot)
sudo mkdir -p /mnt/persist/var/lib/sbctl
sudo cp -r /var/lib/sbctl/. /mnt/persist/var/lib/sbctl/
```

**`Exactly one of isSystemUser and isNormalUser must be set` / `group is unset`:**
The user definition in `hosts/configuration.nix` is incomplete. It must be:
```nix
users.users.<name> = {
  isNormalUser = true;
  group        = "<name>";
};
users.groups.<name> = {};
```

**First boot fails — cannot mount `/`:**
The `@root-blank` BTRFS subvolume may be missing. Boot from the live ISO, open LUKS, and check:
```bash
cryptsetup open /dev/disk/by-label/NIXLUKS cryptroot
mkdir -p /tmp/btrfs_root
mount -o subvol=/ /dev/mapper/cryptroot /tmp/btrfs_root
btrfs subvolume list /tmp/btrfs_root
# If @root-blank is missing:
btrfs subvolume snapshot -r /tmp/btrfs_root/@ /tmp/btrfs_root/@root-blank
umount /tmp/btrfs_root
```

**`/etc/nixos` is empty after first boot:**
The config was not copied to `/persist` before rebooting. Fix by cloning or copying:
```bash
sudo git clone https://github.com/atirelli3/NERV.nixos.git /etc/nixos
sudo vim /etc/nixos/hosts/configuration.nix  # re-apply your values
```

**User cannot log in after first boot:**
`nixos-install` only sets the root password. Set the user password before rebooting:
```bash
sudo nixos-enter --root /mnt
passwd <username>
exit
```

**SSH fingerprint mismatch after reboot:**
Verify that `/persist/etc/ssh` contains the host keys and that impermanence mounted correctly.
Check `systemctl status persist-etc-ssh.mount`.

**Home Manager build fails with "file not found":**
Every user listed in `nerv.home.users` must have a `~/home.nix` before running `nixos-rebuild`.
Ensure the file exists at `/home/<username>/home.nix`.
