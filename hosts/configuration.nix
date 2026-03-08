# hosts/configuration.nix
#
# Purpose  : Machine identity for this NERV.nixos installation.
# Role     : Declares machine-specific values only. All service and feature
#            settings are controlled by the profile in flake.nix (hostProfile,
#            serverProfile, or vmProfile).
# Entry    : nerv.hostname, nerv.primaryUser, nerv.hardware.*, nerv.locale.*,
#            system.stateVersion, disko.devices.disk.main.device
# Override : Edit this file. Replace all PLACEHOLDER values before first boot.
# Note     : hardware-configuration.nix is a placeholder — replace with the
#            output of nixos-generate-config on the target machine.
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.networkmanager.enable = true;

  # Replace PLACEHOLDER with the actual username (e.g. "alice").
  users.users.PLACEHOLDER = { isNormalUser = true; };

  system.stateVersion = "25.11";

  # Machine identity — replace all PLACEHOLDER values.
  nerv.hostname     = "PLACEHOLDER";           # e.g. "my-desktop"
  nerv.primaryUser  = [ "PLACEHOLDER" ];       # e.g. [ "alice" ]

  nerv.hardware.cpu = "PLACEHOLDER";           # "amd" | "intel" | "other"
  nerv.hardware.gpu = "PLACEHOLDER";           # "amd" | "nvidia" | "intel" | "none"

  nerv.locale.timeZone      = "PLACEHOLDER";   # e.g. "Europe/Rome"
  nerv.locale.defaultLocale = "PLACEHOLDER";   # e.g. "en_US.UTF-8"
  nerv.locale.keyMap        = "PLACEHOLDER";   # e.g. "us"

  # Disk device for disko — replace with the actual target disk.
  # Find with: lsblk -d -o NAME,SIZE,MODEL
  disko.devices.disk.main.device = "/dev/PLACEHOLDER";  # e.g. "/dev/nvme0n1"
}
