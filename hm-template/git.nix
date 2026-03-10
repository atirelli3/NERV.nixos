# hm-template/git.nix
#
# Git identity, SSH commit signing, and SSH client config.

{ config, lib, pkgs, ... }:

{
  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable    = true;
    userName  = "PLACEHOLDER";   # e.g. "Ada Lovelace"
    userEmail = "PLACEHOLDER";   # e.g. "ada@example.com"

    extraConfig = {
      gpg.format = "ssh";        # use SSH key for commit signing
    };

    signing = {
      key           = "~/.ssh/id_ed25519.pub"; # path to your SSH public key
      signByDefault = true;
    };
  };

  # ── SSH client ────────────────────────────────────────────────────────────
  # Manages ~/.ssh/config. Add a matchBlock per remote host you use.
  programs.ssh = {
    enable = true;

    matchBlocks = {
      # "github.com" = {
      #   user         = "git";
      #   identityFile = "~/.ssh/id_ed25519";
      # };
    };
  };
}
