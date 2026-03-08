# modules/system/boot.nix
#
# Purpose : initrd (systemd + LVM + LUKS) and bootloader (systemd-boot + EFI) configuration.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : boot.kernelPackages = pkgs.linuxPackages_latest is set here but
#           overridden by kernel.nix (lib.mkForce pkgs.linuxPackages_zen) —
#           kernel.nix is the authoritative source for the kernel package.
# LUKS    : NIXLUKS label must stay in sync with hosts/nixos-base/disko-configuration.nix
#           and modules/system/secureboot.nix.

{ config, lib, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.systemd.enable = true;   # required for services.lvm and crypttabExtraOpts
  boot.initrd.services.lvm.enable = true;
  boot.initrd.kernelModules = [ "dm-snapshot" "cryptd" ];  # LVM-on-LUKS snapshots and async dm-crypt
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-label/NIXLUKS";  # must match disko-configuration.nix and secureboot.nix
    preLVM = true;
    allowDiscards = true;  # TRIM pass-through for SSDs
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
