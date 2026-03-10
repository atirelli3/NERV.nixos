# modules/system/default.nix
#
# Purpose  : Aggregates all nerv system modules.
# Modules  : identity, hardware, kernel, security, nix, packages, boot, impermanence, disko, secureboot
# Note     : secureboot.nix must be last — it applies lib.mkForce false on systemd-boot
#            to prevent conflict with Lanzaboote. Import order is significant.
{ imports = [
    ./identity.nix
    ./hardware.nix
    ./kernel.nix
    ./security.nix
    ./nix.nix
    ./packages.nix      # base system packages shipped on all flavors (git, fastfetch)
    ./boot.nix          # initrd + LUKS + bootloader (opaque)
    ./impermanence.nix  # selective per-directory tmpfs (enable = false by default)
    ./disko.nix         # declarative disk layout — conditional LVM LVs based on impermanence mode
    ./secureboot.nix    # Lanzaboote + TPM2 — must be last (lib.mkForce false on systemd-boot)
  ];
}
