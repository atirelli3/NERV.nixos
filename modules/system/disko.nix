# modules/system/disko.nix
#
# Declarative disk layout and layout-conditional initrd config. btrfs (desktop) or lvm (server). No default — must be set explicitly.
# Profiles : host layout=btrfs | server layout=lvm

{ config, lib, pkgs, ... }:

let
  cfg     = config.nerv.disko;
  isBtrfs = cfg.layout == "btrfs";
  isLvm   = cfg.layout == "lvm";

  sharedEsp = {
    size = "1G";
    type = "EF00";
    content = {
      type         = "filesystem";
      format       = "vfat";
      mountpoint   = "/boot";
      mountOptions = [ "fmask=0077" "dmask=0077" ];
      extraArgs    = [ "-n" "NIXBOOT" ];
    };
  };

  sharedLuksOuter = content: {
    size = "100%";
    content = {
      type                   = "luks";
      name                   = "cryptroot";
      settings.allowDiscards = true;   # TRIM pass-through for SSDs
      extraFormatArgs        = [ "--label" "NIXLUKS" ];  # must stay in sync with boot.nix and secureboot.nix
      passwordFile           = "/tmp/luks-password";     # pre-seeded by the install script
      inherit content;
    };
  };
in {
  options.nerv.disko = {
    layout = lib.mkOption {
      type        = lib.types.enum [ "btrfs" "lvm" ];
      # intentionally no default — forces explicit declaration per host;
      # consistent with nerv.hostname, nerv.hardware.cpu, nerv.hardware.gpu.
      description = ''
        Disk layout type.
          btrfs — GPT/LUKS/BTRFS with subvolumes (desktop/laptop).
          lvm   — GPT/LUKS/LVM with swap, /nix, /persist LVs (server).
      '';
    };

    lvm = {
      swapSize = lib.mkOption {
        type        = lib.types.str;
        default     = "PLACEHOLDER";
        description = "Swap LV size (lvm layout only). Set to 2x physical RAM. Find RAM with: free -h";
        example     = "16G";
      };
      storeSize = lib.mkOption {
        type        = lib.types.str;
        default     = "PLACEHOLDER";
        description = "Nix store LV size (lvm layout only — /nix ext4). Inspect with: nix path-info --all | wc -c";
        example     = "60G";
      };
      persistSize = lib.mkOption {
        type        = lib.types.str;
        default     = "PLACEHOLDER";
        description = "Persist LV size (lvm layout only — /persist ext4). Holds SSH keys, service state, etc.";
        example     = "20G";
      };
    };

    btrfs.zram = {
      enable = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Enable zram compressed swap (BTRFS layout only). Creates /dev/zram0 sized at memoryPercent of physical RAM.";
      };
      memoryPercent = lib.mkOption {
        type        = lib.types.ints.between 1 100;
        default     = 50;
        description = "Maximum zram swap size as a percentage of total RAM. The default (50 %) gives a 2:1 headroom for zstd-compressed pages.";
        example     = 25;
      };
    };
  };

  config = lib.mkMerge [

    # ── zram layout guard (fires on any layout when zram.enable = true) ─────
    (lib.mkIf cfg.btrfs.zram.enable {
      assertions = [{
        assertion = isBtrfs;
        message   = ''
          nerv: nerv.disko.btrfs.zram.enable requires
            nerv.disko.layout = "btrfs".
            The LVM layout provides disk-based swap via the swap LV.
            Disable zram or switch to the btrfs layout.
        '';
      }];
    })

    # ── BTRFS branch ─────────────────────────────────────────────────────
    (lib.mkIf isBtrfs {
      disko.devices.disk.main = {
        # device is merged from disko.devices.disk.main.device in hosts/configuration.nix
        type    = "disk";
        content = {
          type       = "gpt";
          partitions = {
            ESP  = sharedEsp;
            luks = sharedLuksOuter {
              type      = "btrfs";
              extraArgs = [ "-L" "NIXBTRFS" "-f" ];  # -L sets label; -f forces creation
              subvolumes = {
                "/@" = {
                  mountpoint   = "/";
                  mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
                };
                "/@root-blank" = {};  # no mountpoint — rollback snapshot baseline (see Phase 10)
                "/@home" = {
                  mountpoint   = "/home";
                  mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
                };
                "/@nix" = {
                  mountpoint   = "/nix";
                  mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
                };
                "/@persist" = {
                  mountpoint   = "/persist";
                  mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
                };
                "/@log" = {
                  mountpoint   = "/var/log";
                  mountOptions = [ "compress=zstd:3" "noatime" "space_cache=v2" ];
                };
              };
            };
          };
        };
      };

      # BTRFS initrd: filesystem driver + rollback service
      boot.initrd.supportedFilesystems = [ "btrfs" ];
      boot.initrd.systemd.storePaths   = [ pkgs.btrfs-progs ];

      boot.initrd.systemd.services.rollback = {
        description = "Rollback BTRFS root subvolume to a pristine state";
        wantedBy    = [ "initrd.target" ];
        after       = [ "dev-mapper-cryptroot.device" ];
        before      = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /btrfs_tmp
          mount -o subvol=/ /dev/mapper/cryptroot /btrfs_tmp
          if [ -e /btrfs_tmp/@ ]; then
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete /btrfs_tmp/@ || true
          fi
          ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot \
            /btrfs_tmp/@root-blank /btrfs_tmp/@
          umount /btrfs_tmp
        '';
      };

      # ── zram compressed swap (BTRFS only) ────────────────────────────────
      # Activated only when nerv.disko.btrfs.zram.enable = true.
      # Note: kernel.nix sets init_on_free=1. Heavy zram usage under zstd adds
      # CPU overhead (decompression on page-out) — acceptable on desktop workloads.
      zramSwap = lib.mkIf cfg.btrfs.zram.enable {
        enable        = true;
        memoryPercent = cfg.btrfs.zram.memoryPercent;
        priority      = 100;  # prefer zram over any other swap source
        # algorithm hardcoded to zstd in v3.0; use lib.mkForce to override.
        algorithm     = lib.mkForce "zstd";
      };
    })

    # ── LVM branch (server-only) ──────────────────────────────────────────
    (lib.mkIf isLvm {
      disko.devices.disk.main = {
        # device is merged from disko.devices.disk.main.device in hosts/configuration.nix
        type    = "disk";
        content = {
          type       = "gpt";
          partitions = {
            ESP  = sharedEsp;
            luks = sharedLuksOuter {
              type = "lvm_pv";
              vg   = "lvmroot";
            };
          };
        };
      };

      disko.devices.lvm_vg.lvmroot = {
        type = "lvm_vg";
        lvs  = {
          swap = {
            size    = cfg.lvm.swapSize;
            content = {
              type      = "swap";
              extraArgs = [ "-L" "NIXSWAP" ];
            };
          };
          store = {
            size    = cfg.lvm.storeSize;
            content = {
              type       = "filesystem";
              format     = "ext4";
              mountpoint = "/nix";
              extraArgs  = [ "-L" "NIXSTORE" ];
            };
          };
          persist = {
            size    = cfg.lvm.persistSize;
            content = {
              type       = "filesystem";
              format     = "ext4";
              mountpoint = "/persist";
              extraArgs  = [ "-L" "NIXPERSIST" ];
              # neededForBoot is set by modules/system/impermanence.nix (mode = "btrfs"/"full")
              # so impermanence bind mounts are available before services start.
            };
          };
        };
      };

      # LVM initrd: LVM activation and dm-snapshot support
      boot.initrd.services.lvm.enable = true;
      boot.initrd.kernelModules       = [ "dm-snapshot" "cryptd" ];
    })

  ];
}
