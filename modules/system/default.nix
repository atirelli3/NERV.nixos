# modules/system/default.nix
#
# Aggregates all nerv system modules. secureboot.nix must be last — applies lib.mkForce false on systemd-boot.
{ imports = [
    ./identity.nix
    ./hardware.nix
    ./kernel.nix
    ./security.nix
    ./nix.nix
    ./packages.nix      # base system packages shipped on all flavors (git, fastfetch)
    ./boot.nix          # initrd + LUKS + bootloader (opaque)
    ./impermanence.nix  # selective per-directory tmpfs (enable = false by default)
    ./disko.nix         # declarative disk layout (btrfs/lvm) with layout-conditional initrd services
    ./secureboot.nix    # Lanzaboote + TPM2 — must be last (lib.mkForce false on systemd-boot)
  ];
}
