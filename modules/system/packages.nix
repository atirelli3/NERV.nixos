# modules/system/packages.nix
#
# Base system packages shipped unconditionally across all NERV flavors — git and fastfetch.

{ pkgs, ... }:

{
  programs.git.enable              = true;
  environment.systemPackages       = [ pkgs.fastfetch ];
}
