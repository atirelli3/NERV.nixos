# Features Research: nerv.nixos v2.0

**Project:** nerv.nixos — Stateless Disk Layout (BTRFS + impermanence)
**Focus:** Desktop BTRFS rollback, server tmpfs root, upstream impermanence module
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| BTRFS subvolumes: @, @root-blank, @home, @nix, @persist | Core of BTRFS impermanence; missing any breaks rollback or persistence | MEDIUM | @root-blank is the clean snapshot used for reset |
| initrd BTRFS rollback (delete @, snapshot @root-blank → @) | Without this root is NOT reset on reboot — defeats stateless design | HIGH | Must use `boot.initrd.systemd.services` — boot.nix already enables systemd initrd |
| Upstream impermanence module (environment.persistence) | Community-standard declarative persistence API; much cleaner than custom tmpfiles.rules | MEDIUM | `impermanence.nixosModules.impermanence` already in flake inputs, just unused |
| Minimum persistence rules (machine-id, SSH host keys, /var/lib, /var/log) | System breaks without machine-id; SSH host key changes = operator alarm | LOW | Reuse existing impermanence.nix full-mode rules |
| Server tmpfs root (fileSystems."/" = { fsType = "tmpfs"; }) | Server profile must have RAM root + disk-only /nix and /persist | MEDIUM | size=2G conventional default; neededForBoot on /persist |
| BTRFS mount options (compress=zstd, noatime, space_cache=v2) | All community patterns use these for correctness and performance | LOW | Set via disko mountOptions |
| nerv.disko.layout option ("btrfs" or "lvm") | Drives which disk layout disko.nix emits per profile | LOW | desktop→btrfs, server/vm→lvm |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| @log subvolume | Preserves logs across rollbacks for desktop debugging | LOW | Optional; mount at /var/log |
| Configurable tmpfsSize | Prevents OOM on servers with small RAM | LOW | nerv.disko.tmpfsSize, default "2G" |
| nerv.impermanence.extraDirs user-facing | Operator extends persistence without editing module source | LOW | Already implemented; expose at profile level |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full $HOME on tmpfs | "Everything ephemeral" | User data loss on reboot; HM activation failures | @home BTRFS subvolume — persistent, no data loss |
| Snapper integration | Automatic BTRFS snapshots | Orthogonal concern; daemon + config complexity | Out of scope for base library |
| BTRFS RAID | Data redundancy | Multi-disk assumption breaks single-disk disko layout | Out of scope |
| Automated LVM→BTRFS migration | Existing systems want to migrate | Backup/restore is user responsibility; too risky to automate | Document manual migration path |

## Feature Dependencies

```
nerv.disko.layout = "btrfs" (desktop/host)
    └──requires──> disko BTRFS content type (subvolumes attrset)
    └──requires──> LUKS content containing btrfs (NOT lvm_pv)

initrd rollback service
    └──requires──> @root-blank subvolume exists (created at install time)
    └──requires──> boot.initrd.systemd.enable = true (already in boot.nix)
    └──After──> dev-mapper-cryptroot.device
    └──Before──> sysroot.mount

environment.persistence."/persist"
    └──requires──> impermanence.nixosModules.impermanence in modules list
    └──requires──> /persist neededForBoot = true
    └──requires──> upstream module replaces custom bind-mount logic in impermanence.nix

nerv.disko.layout = "lvm" (server/vm)
    └──requires──> fileSystems."/" = tmpfs (from impermanence.nix full mode)
    └──requires──> /nix on separate LV (storeSize option)
    └──requires──> /persist on separate LV (persistSize option)
```

### Dependency Notes

- **BTRFS layout uses luks → btrfs directly** (not luks → lvm_pv): disk content chain changes for desktop
- **initrd rollback requires systemd initrd**: `postDeviceCommands` is incompatible with systemd initrd; must use `boot.initrd.systemd.services`
- **environment.persistence requires neededForBoot on /persist**: upstream module bind-mounts happen during systemd activation phase — /persist must be mounted first

## MVP Definition

### Launch With (v2.0)

- [ ] BTRFS disko layout for desktop/host profile — subvolumes @, @root-blank, @home, @nix, @persist
- [ ] initrd systemd rollback service — delete @, snapshot @root-blank → @ before sysroot.mount
- [ ] Upstream impermanence module wired (environment.persistence in both profiles)
- [ ] Minimum persistence rules — machine-id, SSH host keys, /var/log, /var/lib, /etc/nixos
- [ ] Server/vm profile retains LVM layout — swap + store (/nix) + persist (/persist)
- [ ] nerv.disko.layout option — "btrfs" | "lvm" — drives which disko branch is emitted

### Add After Validation (v2.x)

- [ ] @log subvolume — optional persistent logs across desktop reboots
- [ ] Configurable tmpfsSize for server profile
- [ ] Per-user environment.persistence blocks

### Future Consideration (v3+)

- [ ] Snapper integration — automatic BTRFS snapshots with rotation
- [ ] BTRFS compression level option

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| BTRFS disko layout | HIGH | MEDIUM | P1 |
| initrd rollback service | HIGH | HIGH | P1 |
| Upstream impermanence module | HIGH | MEDIUM | P1 |
| Minimum persistence rules | HIGH | LOW | P1 |
| nerv.disko.layout option | MEDIUM | LOW | P1 |
| @log subvolume | LOW | LOW | P2 |
| Configurable tmpfsSize | LOW | LOW | P2 |

## Sources

- disk-layout-refactor.md — project design specification
- willbush.dev/blog/impermanent-nixos — BTRFS initrd rollback NixOS pattern
- xeiaso.net/blog/paranoid-nixos-2021-07-18 — tmpfs root server pattern
- github.com/nix-community/impermanence — upstream module API (environment.persistence)

---
*Feature research for: nerv.nixos v2.0 stateless disk layout*
*Researched: 2026-03-09*
