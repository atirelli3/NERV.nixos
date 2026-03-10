# hm-template/home.nix
#
# Root Home Manager config. Copy this entire hm-template/ directory to ~/
# and rename it — or copy individual files and import them from your ~/home.nix.
# Add your username to nerv.home.users in hosts/configuration.nix, then:
#   nixos-rebuild switch --flake /etc/nixos#host --impure

{ config, lib, pkgs, osConfig, ... }:

{
  imports = [
    ./git.nix
    ./hyprland.nix
    ./ghostty.nix
    ./rofi.nix
  ];

  # ── Identity ──────────────────────────────────────────────────────────────
  home.username     = "PLACEHOLDER";   # must match your system user account
  home.homeDirectory = "/home/PLACEHOLDER";
  # stateVersion is inherited from the system — do not set it here.

  # ── Packages ──────────────────────────────────────────────────────────────
  # Uncomment and extend as needed. Prefer programs.* options in the sub-files
  # where available — they provide richer integration than a bare package entry.
  #
  # home.packages = with pkgs; [
  #   zen-browser
  #   btop
  #   ripgrep
  # ];

  # ── Display manager: ly ───────────────────────────────────────────────────
  # ly is a system-level service — not configurable from Home Manager.
  # Add to hosts/configuration.nix:
  #
  #   services.displayManager.ly.enable = true;

  # ── OpenSSH daemon (system-level) ─────────────────────────────────────────
  # The SSH daemon is managed by the system repo, not Home Manager.
  # Add to hosts/configuration.nix:
  #
  #   nerv.openssh.enable             = true;
  #   nerv.openssh.allowUsers         = [ "PLACEHOLDER" ];
  #   nerv.openssh.passwordAuth       = false;
  #   nerv.openssh.kbdInteractiveAuth = false;
  #   nerv.openssh.port               = 2222;
  #
  # See modules/services/openssh.nix for the full option reference.
}
