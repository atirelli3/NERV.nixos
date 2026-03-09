# Architecture Research: nerv.nixos v2.0

**Project:** nerv.nixos — Stateless Disk Layout (BTRFS + impermanence)
**Focus:** Integration points for BTRFS disko + initrd rollback + upstream impermanence module
**Confidence:** HIGH (based on direct codebase analysis)

## Current Architecture (v1.0 baseline)

```
flake.nix
├── inputs: disko v1.13.0, impermanence (already both wired)
├── hostProfile:   nerv.impermanence.mode = "minimal"  → /tmp + /var/tmp as tmpfs
├── serverProfile: nerv.impermanence.mode = "full"     → / as tmpfs + environment.persistence
└── vmProfile:     nerv.impermanence.mode = "minimal"

modules/system/
├── disko.nix         (NEW in pre-v2.0 work)
│   ├── nerv.disko.{swapSize, rootSize, storeSize, persistSize}
│   ├── minimal mode → LVM: swap + root (/)
│   └── full mode    → LVM: swap + store (/nix) + persist (/persist)
├── boot.nix          (opaque)
│   ├── boot.initrd.systemd.enable = true  ← CRITICAL: blocks postDeviceCommands
│   ├── boot.initrd.services.lvm.enable = true
│   └── boot.initrd.luks.devices."cryptroot" = /dev/disk/by-label/NIXLUKS
└── impermanence.nix
    ├── minimal → /tmp + /var/tmp as tmpfs
    └── full    → / as tmpfs + environment.persistence."/persist" (upstream module)
```

## Target Architecture (v2.0)

```
flake.nix (profile changes only)
├── hostProfile:   nerv.disko.layout = "btrfs" + nerv.impermanence.mode = "btrfs"
├── serverProfile: nerv.disko.layout = "lvm"   + nerv.impermanence.mode = "full"  (unchanged)
└── vmProfile:     nerv.disko.layout = "lvm"   + nerv.impermanence.mode = "minimal" (unchanged)

modules/system/
├── disko.nix         (MODIFIED)
│   ├── nerv.disko.layout option: "btrfs" | "lvm"  (NEW)
│   ├── btrfs branch → GPT: ESP + LUKS → btrfs subvolumes (@, @root-blank, @home, @nix, @persist)
│   └── lvm branch   → GPT: ESP + LUKS → lvm_pv → lvm_vg → {swap, root|store+persist}  (existing)
├── boot.nix          (MODIFIED — add btrfs initrd support when layout = "btrfs")
│   ├── boot.initrd.supportedFilesystems = ["btrfs"]  (conditional on layout = "btrfs")
│   └── boot.initrd.systemd.services.rollback  (NEW — conditional on layout = "btrfs")
│       ├── after: dev-mapper-cryptroot.device
│       ├── before: sysroot.mount
│       └── script: mount /dev/mapper/cryptroot, delete @, snapshot @root-blank → @, umount
└── impermanence.nix  (MODIFIED — add "btrfs" mode)
    ├── minimal → /tmp + /var/tmp as tmpfs (unchanged)
    ├── full    → / as tmpfs + environment.persistence (unchanged, server)
    └── btrfs   → NO tmpfs / (rollback resets @ in initrd) + environment.persistence."/persist"
                  neededForBoot on /persist (via @persist subvolume)
```

## Component Changes

### Modified: modules/system/disko.nix

**Add:** `nerv.disko.layout` option (`types.enum ["btrfs" "lvm"]`)

**Add:** BTRFS branch in `config.disko.devices`:
```
disk.main.content.partitions.luks.content = {
  type = "luks";
  name = "cryptroot";  # must stay "cryptroot" — matches boot.nix and secureboot.nix
  settings.allowDiscards = true;
  extraFormatArgs = ["--label" "NIXLUKS"];
  content = if isBtrfsLayout then {
    type = "btrfs";
    extraArgs = ["-L" "NIXBTRFS" "-f"];
    subvolumes = {
      "@"           = { mountpoint = "/"; mountOptions = ["compress=zstd:3" "noatime" "subvol=@"]; };
      "@root-blank" = {};  # no mountpoint — snapshot only, not mounted at boot
      "@home"       = { mountpoint = "/home"; mountOptions = ["compress=zstd:3" "noatime" "subvol=@home"]; };
      "@nix"        = { mountpoint = "/nix";  mountOptions = ["compress=zstd:3" "noatime" "subvol=@nix"]; };
      "@persist"    = { mountpoint = "/persist"; mountOptions = ["compress=zstd:3" "noatime" "subvol=@persist"]; };
    };
  } else { type = "lvm_pv"; vg = "lvmroot"; };
```

**Swap LV:** Only emit swap LV when layout = "lvm" (BTRFS uses a swapfile on @persist instead, or no swap).

### Modified: modules/system/boot.nix

**Add (conditional on nerv.disko.layout = "btrfs"):**
```nix
boot.initrd.supportedFilesystems = ["btrfs"];

boot.initrd.systemd.services.rollback = {
  description = "Roll back BTRFS root subvolume to blank snapshot";
  wantedBy    = ["initrd.target"];
  after       = ["dev-mapper-cryptroot.device"];
  before      = ["sysroot.mount"];
  unitConfig.DefaultDependencies = "no";
  serviceConfig.Type = "oneshot";
  script = ''
    mount -t btrfs -o subvol=/ /dev/mapper/cryptroot /mnt
    btrfs subvolume delete /mnt/@
    btrfs subvolume snapshot /mnt/@root-blank /mnt/@
    umount /mnt
  '';
};
```

**Remove (conditional on layout = "lvm" only):**
- `boot.initrd.services.lvm.enable = true` — currently always on; should be behind layout = "lvm" guard
- `boot.initrd.kernelModules = ["dm-snapshot" "cryptd"]` — dm-snapshot not needed for BTRFS

**LUKS config stays unchanged:** `boot.initrd.luks.devices."cryptroot"` points to NIXLUKS label — same regardless of layout; LUKS wraps both BTRFS and LVM.

### Modified: modules/system/impermanence.nix

**Add "btrfs" to mode enum:**
```nix
mode = lib.mkOption {
  type = lib.types.enum ["minimal" "full" "btrfs"];
  ...
};
```

**Add btrfs mode block:**
```nix
(lib.mkIf (cfg.mode == "btrfs") {
  # @ is reset in initrd — no tmpfs / needed
  # /persist is the @persist subvolume (mounted by disko, neededForBoot set by disko)
  environment.persistence."${cfg.persistPath}" = {
    hideMounts = true;
    directories = ["/var/log" "/var/lib/nixos" "/var/lib/systemd" "/etc/nixos"];
    files = ["/etc/machine-id" "/etc/ssh/ssh_host_ed25519_key" ...];
  };
})
```

### Modified: flake.nix (profiles only)

```nix
hostProfile = {
  nerv.disko.layout      = "btrfs";  # NEW
  nerv.impermanence.mode = "btrfs";  # CHANGED from "minimal"
  ...
};
```

serverProfile and vmProfile: add `nerv.disko.layout = "lvm"` (explicit; behavior unchanged).

### Not Modified

- modules/system/identity.nix, hardware.nix, kernel.nix, security.nix, nix.nix, packages.nix
- modules/services/* (all service modules unchanged)
- home/default.nix
- hosts/configuration.nix — add `nerv.disko.layout` placeholder value

## Build Order (Phases)

1. **disko.nix BTRFS branch** — disk layout foundation (everything else depends on correct subvolumes)
2. **boot.nix rollback service** — initrd rollback (depends on knowing LUKS device name from disko)
3. **impermanence.nix btrfs mode** — persistence rules (depends on @persist subvolume from disko)
4. **flake.nix profile update + documentation** — wire profiles and document all changes
5. **Validation** — nix flake check + install walkthrough documentation

## Integration Points

| Component | Change Type | Depends On |
|-----------|-------------|-----------|
| disko.nix | Modified — new layout option + BTRFS branch | Nothing new |
| boot.nix | Modified — rollback service + btrfs filesystems | nerv.disko.layout value |
| impermanence.nix | Modified — new "btrfs" mode | @persist subvolume from disko |
| flake.nix hostProfile | Modified — layout + mode values | disko.nix + impermanence.nix |
| hosts/configuration.nix | Modified — nerv.disko.layout placeholder | disko.nix |

## Sources

- modules/system/disko.nix (existing LVM layout to extend)
- modules/system/boot.nix (systemd initrd confirmed, LVM services)
- modules/system/impermanence.nix (full mode pattern to replicate for btrfs mode)
- flake.nix (profile definitions, module wiring)
- NixOS wiki: BTRFS impermanence + initrd systemd rollback service pattern

---
*Architecture research for: nerv.nixos v2.0 stateless disk layout*
*Researched: 2026-03-09*
