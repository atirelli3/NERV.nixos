# modules/system/boot.nix
#
# Purpose : Layout-agnostic initrd and bootloader configuration (systemd stage 1,
#           systemd-boot, EFI). Layout-specific initrd (BTRFS rollback service,
#           LVM lvm.enable, LUKS unlock) lives in modules/system/disko.nix.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : boot.kernelPackages = pkgs.linuxPackages_latest is set here but
#           overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) —
#           kernel.nix is the authoritative source for the kernel package.

{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.systemd.enable = true;  # required for boot.initrd.systemd.services.* (rollback service in disko.nix)

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
