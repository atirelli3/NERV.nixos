# modules/system/boot.nix
#
# Layout-agnostic initrd and bootloader (systemd-boot + EFI). Layout-specific initrd config lives in disko.nix.
# Profiles : host | server

{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.systemd.enable = true;  # required for boot.initrd.systemd.services.* (rollback service in disko.nix)

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
