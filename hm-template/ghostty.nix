# hm-template/ghostty.nix
#
# Ghostty terminal emulator.

{ config, lib, pkgs, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      font-size        = 13;
      # font-family    = "JetBrains Mono";
      theme            = "dark:catppuccin-mocha,light:catppuccin-latte";
      window-padding-x = 8;
      window-padding-y = 8;
    };
  };
}
