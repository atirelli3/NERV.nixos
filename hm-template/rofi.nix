# hm-template/rofi.nix
#
# Rofi application launcher (Wayland-native fork).

{ config, lib, pkgs, ... }:

{
  programs.rofi = {
    enable   = true;
    package  = pkgs.rofi-wayland;      # drop -wayland if running on X11
    terminal = "${pkgs.ghostty}/bin/ghostty";
    # theme  = "PLACEHOLDER";          # path to a .rasi theme file
  };
}
