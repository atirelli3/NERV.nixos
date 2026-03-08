# hosts/disko-configuration.nix
#
# !! WARNING — PLACEHOLDER VALUES MUST BE REPLACED BEFORE USE !!
#
#   /dev/DISK      Replace with the actual target disk, e.g. "/dev/nvme0n1"
#                  Find with: lsblk -d -o NAME,SIZE,MODEL
#   SIZE_RAM * 2   Replace swap size with a concrete value, e.g. "16G" (2x physical RAM).
#                  Find RAM size with: free -h
#   SIZE (store)   Replace with Nix store size, e.g. "60G". Should accommodate
#                  all NixOS generations. Inspect with: nix path-info --all | wc -c
#   SIZE (persist) Replace with persistent state size, e.g. "20G". Holds /var/log,
#                  /etc/nixos, SSH host keys, and any service state.
#
# Purpose  : Disko declarative disk layout for server full-impermanence profile.
#            GPT / EFI / LUKS-on-LVM. Root (/) is NOT declared here — it is a
#            tmpfs declared by modules/system/impermanence.nix (mode = "full").
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
              extraFormatArgs = [ "--label" "NIXLUKS" ];  # NIXLUKS — must stay in sync with modules/system/boot.nix and modules/system/secureboot.nix
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
        store = {
          size = "SIZE";  # placeholder — replace with e.g. "60G" for the Nix store
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
            extraArgs = [ "-L" "NIXSTORE" ];
          };
        };
        persist = {
          size = "SIZE";  # placeholder — replace with e.g. "20G" for persistent state
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
            extraArgs = [ "-L" "NIXPERSIST" ];
            # /persist.neededForBoot is set by modules/system/impermanence.nix (mode = "full")
            # so impermanence bind mounts can happen before services start.
          };
        };
        # No root LV — / is a tmpfs declared in modules/system/impermanence.nix (mode = "full").
        # This means / resets on every reboot; only paths under /persist survive.
        # No home LV — /home is ephemeral (created under tmpfs root) for servers.
        # Add environment.persistence."/persist".directories = [ "/home/user" ] if needed.
      };
    };
  };
}
