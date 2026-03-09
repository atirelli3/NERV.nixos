# modules/system/packages.nix
#
# Purpose  : Base system packages shipped unconditionally across all NERV flavors
#            (host, vm, server). No enable option — these are always present.
# Packages : git       — version control; required for nix flake operations.
#            fastfetch — system info display with custom NERV ASCII logo.
# Note     : programs.fastfetch handles the fastfetch package; git is explicit
#            in systemPackages. Logo uses fastfetch $N color tokens:
#            $1 = steel blue (snowflake), $2 = red (NERV text + Adam silhouette).

{ pkgs, ... }:

{
  programs.git.enable              = true;
  environment.systemPackages       = [ pkgs.fastfetch ];
}
