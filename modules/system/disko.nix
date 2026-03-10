# modules/system/disko.nix
#
# Purpose  : Declarative disk layout (GPT / EFI / LUKS) AND all layout-conditional
#            initrd configuration. Supports two layout types controlled by
#            nerv.disko.layout (no default — must be set explicitly):
#              btrfs — GPT/LUKS/BTRFS with subvolumes + rollback service (desktop/laptop)
#              lvm   — GPT/LUKS/LVM with swap, /nix, /persist LVs (server)
#            The disk device is set independently via disko.devices.disk.main.device
#            in hosts/configuration.nix and merged here by the module system.
# Options  : nerv.disko.layout (enum, no default)
#            nerv.disko.lvm.swapSize, nerv.disko.lvm.storeSize, nerv.disko.lvm.persistSize
# LUKS     : NIXLUKS label must stay in sync with modules/system/secureboot.nix.
#            boot.initrd.luks.devices."cryptroot" is declared here (unconditional)
#            and must NOT be re-declared in boot.nix.

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
  };

  config = lib.mkMerge [

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

    # ── Shared: LUKS unlock (both layouts) ───────────────────────────────
    # Both BTRFS and LVM layouts use the same outer LUKS container.
    # Label NIXLUKS must stay in sync with sharedLuksOuter.extraFormatArgs
    # and modules/system/secureboot.nix.
    {
      boot.initrd.luks.devices."cryptroot" = {
        device        = "/dev/disk/by-label/NIXLUKS";  # must match sharedLuksOuter.extraFormatArgs and secureboot.nix
        allowDiscards = true;                           # TRIM pass-through for SSDs
        # preLVM is silently ignored by systemd stage 1 — omit here
      };
    }

  ];
}
