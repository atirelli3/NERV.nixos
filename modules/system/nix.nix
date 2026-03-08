# modules/system/nix.nix
#
# Purpose : Nix daemon and nixpkgs configuration — fully opaque.
# Options : None. GC, optimise, and autoUpgrade settings are hardcoded.
#           autoUpgrade toggle is a v2 roadmap item (OPT-V2-01).
# Override: Use lib.mkForce at the host level to override any setting.
{ config, lib, pkgs, ... }:

{
  # Allow proprietary packages (drivers, firmware, some apps).
  nixpkgs.config.allowUnfree = true;

  # Pull and apply NixOS updates from the flake daily.
  # allowReboot = false: updates are staged but require a manual reboot to apply.
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "/etc/nixos#host";
    dates = "daily";
  };

  nix = {
    # Disable legacy channel infrastructure — flakes handle pinning instead.
    channel.enable = false;

    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Only wheel-group users may talk to the Nix daemon.
      allowed-users = [ "@wheel" ];
      # Trusted users can override per-build daemon settings (e.g. add substituters).
      # Add "@wheel" here if you need that for local development.
      trusted-users = [ "root" ];

      # Hardlink identical files in the store after each build — saves disk space incrementally.
      # Complemented by nix.optimise below which runs a full dedup pass on schedule.
      auto-optimise-store = true;

      # Retain build-time dependencies and derivations so nix develop / direnv shells
      # don't need to re-fetch sources after a gc run.
      keep-outputs      = true;
      keep-derivations  = true;
    };

    # Delete store paths unreachable from any GC root.
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 20d";
    };

    # Full store optimisation pass (catches anything auto-optimise-store missed).
    optimise = {
      automatic = true;
      dates     = [ "weekly" ];
    };
  };
}
