# Pitfalls Research: nerv.nixos v2.0

**Project:** nerv.nixos — Stateless Disk Layout (BTRFS + impermanence)
**Focus:** Critical mistakes when adding BTRFS rollback + upstream impermanence to existing NixOS system
**Confidence:** HIGH

## Critical Pitfalls

### P1 — Using postDeviceCommands for BTRFS Rollback (Boot Failure)

**Risk:** CRITICAL — system will not boot

**Symptom:** initrd hangs or kernel panic during boot after adding rollback script.

**Cause:** `boot.initrd.postDeviceCommands` is incompatible with `boot.initrd.systemd.enable = true`. boot.nix already sets `systemd.enable = true`. The postDeviceCommands hook is part of the stage-1 bash script which is replaced entirely when systemd initrd is active.

**Prevention:** Use `boot.initrd.systemd.services.rollback` — a proper systemd unit that runs in the systemd initrd context.

**Phase to address:** Phase implementing boot.nix rollback service (must verify systemd initrd path first).

---

### P2 — @root-blank Not Created as Read-Only Snapshot (Rollback Corruption)

**Risk:** HIGH — rollback silently does nothing or creates a corrupted @

**Symptom:** Root filesystem not reset after reboot; or btrfs subvolume snapshot fails in initrd.

**Cause:** If @root-blank is a read-write subvolume (default disko creation), snapshots from it are unreliable on concurrent writes. The clean baseline must be a read-only snapshot.

**Prevention:** After first disko run, immediately create the blank snapshot:
```bash
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
```
The `-r` flag creates a read-only snapshot. Document this as a required manual step in the install procedure.

**Phase to address:** Phase documenting install procedure + disko.nix.

---

### P3 — Missing btrfs in boot.initrd.supportedFilesystems (initrd Cannot Mount BTRFS)

**Risk:** CRITICAL — system will not boot after disk layout change

**Symptom:** initrd fails to find root filesystem; drops to emergency shell.

**Cause:** By default, initrd only includes ext4/LVM/LUKS tools. BTRFS tools are not included unless explicitly declared.

**Prevention:**
```nix
boot.initrd.supportedFilesystems = ["btrfs"];
```
This ensures btrfs-progs and kernel module are available in initrd. Guard this behind `nerv.disko.layout = "btrfs"` condition.

**Phase to address:** Phase implementing boot.nix changes (same phase as rollback service).

---

### P4 — Rollback Service Device Path Mismatch (Rollback Never Runs)

**Risk:** HIGH — @ not reset, system appears to work but is not stateless

**Symptom:** Files written before reboot persist in /; rollback service fails silently or systemd marks it as failed.

**Cause:** The rollback script mounts the BTRFS partition by device path. The LUKS device is named "cryptroot" in both boot.nix (`devices."cryptroot"`) and disko.nix (`name = "cryptroot"`). The dm device is therefore `/dev/mapper/cryptroot`.

**Prevention:** Use `/dev/mapper/cryptroot` — NOT `/dev/disk/by-label/NIXBTRFS` (the BTRFS label is inside LUKS, not visible until after unlock). The rollback service runs `after = ["dev-mapper-cryptroot.device"]` which guarantees the LUKS device is open.

```bash
# Correct:
mount -t btrfs -o subvol=/ /dev/mapper/cryptroot /mnt

# Wrong (BTRFS label is inside LUKS — only accessible after unlock, but by-label lookup may fail):
mount -t btrfs -o subvol=/ /dev/disk/by-label/NIXBTRFS /mnt
```

**Phase to address:** Phase implementing boot.nix rollback service.

---

### P5 — machine-id Not Persisted (Journal Corruption on Every Reboot)

**Risk:** HIGH — systemd journals are unusable after any reboot

**Symptom:** `journalctl` shows no logs or logs from wrong machine after reboot; systemd complains about machine-id mismatch.

**Cause:** /etc/machine-id is reset when @ is rolled back. systemd links journal files to the machine-id; a new one each boot means no historical journal access.

**Prevention:**
```nix
environment.persistence."/persist".files = ["/etc/machine-id"];
```
Already in impermanence.nix full mode — must replicate in btrfs mode. Create /persist/etc/machine-id before first boot.

**Phase to address:** Phase implementing impermanence.nix btrfs mode.

---

### P6 — SSH Host Keys Not Persisted (Host Key Changes Every Reboot)

**Risk:** HIGH — operator SSH alerts on every reboot; automation breaks

**Symptom:** SSH client shows "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED" after every reboot.

**Cause:** /etc/ssh/ssh_host_*_key files are reset when @ rolls back. SSH generates new keys if they don't exist.

**Prevention:**
```nix
environment.persistence."/persist".files = [
  "/etc/ssh/ssh_host_ed25519_key"
  "/etc/ssh/ssh_host_ed25519_key.pub"
  "/etc/ssh/ssh_host_rsa_key"
  "/etc/ssh/ssh_host_rsa_key.pub"
];
```
Already in impermanence.nix full mode — must replicate in btrfs mode.

**Phase to address:** Phase implementing impermanence.nix btrfs mode.

---

### P7 — neededForBoot Not Set on @persist (Bind Mounts Fail at Boot)

**Risk:** HIGH — persistence bind mounts fail; services start with wrong state

**Symptom:** Services start without their persisted state; impermanence bind mounts fail with "cannot create directory" errors.

**Cause:** The upstream impermanence module creates bind mounts during early systemd activation. If /persist is not mounted at that point (neededForBoot = false), the bind mounts fail.

**Prevention:**
- In disko.nix BTRFS branch: set `neededForBoot = true` on @persist subvolume mount
- In impermanence.nix btrfs mode: `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` (same as full mode)

Disko sets mountpoints via subvolumes attrset — `neededForBoot` may need to be set separately via a `fileSystems` override since disko-generated mounts do not include this option.

**Phase to address:** Phase implementing disko.nix BTRFS branch + impermanence.nix btrfs mode.

---

### P8 — @nix Not Persisted (Nix Store Lost on Reboot)

**Risk:** CRITICAL — system unbootable after reboot (no NixOS system in /nix/store)

**Symptom:** System loses all installed packages on first reboot after rollback; boot fails.

**Cause:** If @nix subvolume is not declared or not mounted at /nix before rollback, the Nix store is on @ which gets deleted and replaced with @root-blank (empty).

**Prevention:**
- @nix subvolume must be declared in disko BTRFS layout
- /nix must be mounted from @nix subvolume: `neededForBoot = true`
- @nix must be EXCLUDED from rollback — rollback only deletes/recreates @ (root), not @nix

**Phase to address:** Phase implementing disko.nix BTRFS branch (fundamental to correctness).

---

### P9 — Swap on BTRFS Subvolume (Performance Degradation / Errors)

**Risk:** MEDIUM — swap does not work on BTRFS with CoW enabled

**Symptom:** System refuses to activate swap file; kernel errors about swapfile on filesystem with copy-on-write.

**Cause:** BTRFS does not support swap files on CoW subvolumes without special handling (nodatacow attribute on swapfile directory).

**Prevention options:**
1. No swap on BTRFS desktop (if RAM is sufficient) — simplest
2. Swap partition outside BTRFS (small GPT partition before LUKS)
3. Swapfile with `chattr +C` (nodatacow) on containing directory — complex

**Recommendation:** For v2.0, keep LVM swap only for LVM layout. Desktop BTRFS profile: no swap by default (operators can add manually). Remove swap from BTRFS branch in disko.nix.

**Phase to address:** Phase implementing disko.nix BTRFS branch.

---

### P10 — LVM Services Still Active with BTRFS Layout (Harmless but Confusing)

**Risk:** LOW — evaluates correctly but initrd loads unnecessary LVM modules

**Symptom:** `boot.initrd.services.lvm.enable = true` is set globally in boot.nix regardless of disk layout; on BTRFS systems this is unused but not harmful.

**Prevention:** Make `boot.initrd.services.lvm.enable` and `boot.initrd.kernelModules = ["dm-snapshot" "cryptd"]` conditional on `nerv.disko.layout = "lvm"`.

**Phase to address:** Phase implementing boot.nix changes (nice-to-have, not critical).

---

### P11 — Upstream Impermanence Module Double-Declaration

**Risk:** MEDIUM — module system throws evaluation error

**Symptom:** `nix flake check` fails with "The option environment.persistence is defined multiple times".

**Cause:** Both impermanence.nix (full mode) and potentially a new module could declare `environment.persistence`. NixOS module system merges attrsets at the same path but throws on conflicting non-mergeable types.

**Prevention:** Use a single `environment.persistence."${cfg.persistPath}"` block in impermanence.nix for both "full" and "btrfs" modes (extract as a shared let binding to avoid duplication). Do not declare environment.persistence in disko.nix.

**Phase to address:** Phase implementing impermanence.nix btrfs mode.

## Summary by Phase

| Phase | Critical Pitfalls |
|-------|------------------|
| disko.nix BTRFS branch | P3 (btrfs in supportedFilesystems), P8 (@nix subvolume), P9 (no swap on BTRFS), P7 (neededForBoot on @persist) |
| boot.nix rollback service | P1 (postDeviceCommands incompatible), P4 (device path must be /dev/mapper/cryptroot) |
| impermanence.nix btrfs mode | P5 (machine-id), P6 (SSH keys), P7 (neededForBoot), P11 (double-declaration) |
| Disko install procedure | P2 (@root-blank must be read-only snapshot) |
| Profile/flake wiring | P10 (LVM services conditional) |

## Sources

- modules/system/boot.nix (boot.initrd.systemd.enable = true confirmed)
- modules/system/disko.nix (existing LUKS name = "cryptroot")
- modules/system/impermanence.nix (full mode persistence rules to replicate)
- NixOS wiki: Impermanence, BTRFS subvolumes
- github.com/nix-community/impermanence (bind mount timing behavior)

---
*Pitfalls research for: nerv.nixos v2.0 stateless disk layout*
*Researched: 2026-03-09*
