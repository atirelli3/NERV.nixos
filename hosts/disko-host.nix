# hosts/disko-host.nix
#
# !! WARNING — PLACEHOLDER VALUES MUST BE REPLACED BEFORE USE !!
#
#   /dev/DISK      Replace with the actual target disk, e.g. "/dev/nvme0n1"
#                  Find with: lsblk -d -o NAME,SIZE,MODEL
#   SIZE_RAM * 2   Replace swap size with a concrete value, e.g. "16G" (2x physical RAM).
#                  Find RAM size with: free -h
#   SIZE (nix)     Replace with Nix store + root size, e.g. "120G".
#                  Should accommodate all NixOS generations and user data.
#
# Purpose  : Disko declarative disk layout for host/vm profiles (mode = "minimal").
#            GPT / EFI / LUKS-on-LVM. Root (/) is a persistent ext4 LV.
# Options  : None — edit this file directly for the target machine.
# LUKS     : NIXLUKS label must stay in sync with modules/system/boot.nix
#            and modules/system/secureboot.nix.
{
  disko.devices = {
    disk.main = {
      device = "/dev/DISK";  # replace with actual disk, e.g. "/dev/nvme0n1"
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {  # EFI System Partition
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
              extraArgs = [ "-n" "NIXBOOT" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings.allowDiscards = true;  # TRIM pass-through for SSDs
              extraFormatArgs = [ "--label" "NIXLUKS" ];  # must stay in sync with modules/system/boot.nix
              passwordFile = "/tmp/luks-password";  # pre-seeded by the install script
              content = {
                type = "lvm_pv";
                vg = "lvmroot";
              };
            };
          };
        };
      };
    };

    lvm_vg.lvmroot = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = "SIZE_RAM * 2";  # placeholder — replace with e.g. "16G" (2x RAM)
          content = {
            type = "swap";
            extraArgs = [ "-L" "NIXSWAP" ];
          };
        };
        root = {
          size = "SIZE";  # placeholder — replace with e.g. "120G"
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [ "-L" "NIXROOT" ];
          };
        };
      };
    };
  };
}
