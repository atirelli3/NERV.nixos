# home/default.nix
#
# Purpose  : Wires Home Manager as a NixOS module for each user in nerv.home.users.
# Convention: Each listed user owns ~/home.nix. nerv imports it automatically.
#             The user's ~/home.nix does NOT need to set home.stateVersion.
# Options  : nerv.home.enable, nerv.home.users
# Defaults : enable = false; users = []
# Override : lib.mkForce on any home-manager.* setting.
# Note     : nixos-rebuild requires --impure because /home/<name>/home.nix is
#            outside the flake boundary.
#
# User prerequisite: ~/home.nix must exist before nixos-rebuild --impure is run.
# Minimal ~/home.nix:
#   { pkgs, ... }: {
#     home.username    = "<name>";
#     home.homeDirectory = "/home/<name>";
#   }

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.home;
in {
  options.nerv.home = {
    enable = lib.mkEnableOption "Home Manager NixOS module wiring";

    users = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = ''
        Users for whom Home Manager is activated. Each user must maintain
        ~/home.nix containing their personal configuration (packages, programs,
        dotfiles). The system repo does not manage the contents of ~/home.nix.
        Adding a user here automatically imports /home/<name>/home.nix.
        Requires nixos-rebuild --impure.
      '';
      example     = [ "demon" "alice" ];
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.useGlobalPkgs   = true;
    home-manager.useUserPackages = true;
    # Prevents hard failures when HM would overwrite a pre-existing unmanaged file.
    home-manager.backupFileExtension = "backup";

    # Generate home-manager.users attrset from the users list.
    # Each value is a function so it receives osConfig as a module argument,
    # enabling stateVersion inheritance without hardcoding.
    home-manager.users = builtins.listToAttrs (map (name: {
      inherit name;
      value = { osConfig, ... }: {
        imports = [ /home/${name}/home.nix ];
        # Inherit stateVersion from system — user's ~/home.nix need not set this.
        home.stateVersion = osConfig.system.stateVersion;
      };
    }) cfg.users);
  };
}
