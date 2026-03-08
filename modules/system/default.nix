# modules/system/default.nix
#
# Purpose  : Aggregates all nerv system modules.
# Modules  : identity, hardware, kernel, security, nix, boot, impermanence, secureboot
# Note     : secureboot.nix must be last — it applies lib.mkForce false on systemd-boot
#            to prevent conflict with Lanzaboote. Import order is significant.
{ imports = [
    ./identity.nix
    ./hardware.nix
    ./kernel.nix
    ./security.nix
    ./nix.nix
    ./boot.nix          # initrd + LUKS + bootloader (opaque)
    ./impermanence.nix  # selective per-directory tmpfs (enable = false by default)
    ./secureboot.nix    # Lanzaboote + TPM2 — must be last (lib.mkForce false on systemd-boot)
  ];
}
