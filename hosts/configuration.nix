# hosts/configuration.nix
#
# Machine-specific identity — hostname, locale, hardware, and disk device. Replace all PLACEHOLDER values.
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

  # Disk layout type — replace PLACEHOLDER with "btrfs" (desktop/laptop) or "lvm" (server).
  nerv.disko.layout = "PLACEHOLDER";  # "btrfs" for desktop/laptop | "lvm" for server

  # LVM sizes — only relevant when nerv.disko.layout = "lvm". Replace PLACEHOLDER values.
  nerv.disko.lvm.swapSize    = "PLACEHOLDER";  # e.g. "16G"  (2x RAM; free -h)
  nerv.disko.lvm.storeSize   = "PLACEHOLDER";  # e.g. "60G"  (/nix ext4)
  nerv.disko.lvm.persistSize = "PLACEHOLDER";  # e.g. "20G"  (/persist ext4)
}
