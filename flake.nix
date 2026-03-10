{
  description = "nerv — opinionated NixOS base library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Secure Boot bootloader — library dependency, not host dependency.
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager NixOS module — wired in Phase 5.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk layout — generates fileSystems from disko.devices attrset.
    disko = {
      url = "github:nix-community/disko/v1.13.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence NixOS module — environment.persistence for server full mode.
    # Note: impermanence has no nixpkgs input — no follows declaration.
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, lanzaboote, home-manager, disko, impermanence, ... }:
  let
    # Classic desktop/laptop configuration.
    # Defaults applied: nerv.zsh.enable = true, nerv.home.enable = true.
    host = {
      nerv.disko.layout         = "btrfs";  # "btrfs" for desktop/laptop | "lvm" for server
      nerv.openssh.enable       = true;
      nerv.audio.enable         = true;
      nerv.bluetooth.enable     = true;
      nerv.printing.enable      = true;
      nerv.secureboot.enable    = false;    # Enable after running sbctl enroll-keys on the target machine.
      nerv.impermanence.enable  = true;
      nerv.impermanence.mode    = "btrfs";  # "btrfs" (BTRFS rollback) | "full" (/ as tmpfs, server)

      # ── Available options (showing defaults) ────────────────────────────────
      # nerv.home.users                   = [];     # users to wire Home Manager for (e.g. [ "alice" "bob" ])
      #
      # nerv.openssh.port                 = 2222;   # SSH daemon port (port 22 is reserved for the tarpit)
      # nerv.openssh.tarpitPort           = 22;     # endlessh tarpit port
      # nerv.openssh.allowUsers           = [];     # restrict SSH to specific users; empty = all users
      # nerv.openssh.passwordAuth         = false;  # allow password auth (key-based only by default)
      # nerv.openssh.kbdInteractiveAuth   = false;
      #
      # nerv.impermanence.persistPath     = "/persist"; # persistence base path
      # nerv.impermanence.extraDirs       = [];         # extra system paths to mount as tmpfs
      # nerv.impermanence.users           = {};         # per-user tmpfs mounts
      #                                                 # e.g. { alice = { "/home/alice/Videos" = "8G"; }; }
      #
      # # LVM layout options — only relevant when nerv.disko.layout = "lvm"
      # nerv.disko.lvm.swapSize           = "16G"; # swap LV size (2x RAM; check with: free -h)
      # nerv.disko.lvm.storeSize          = "60G"; # /nix LV size
      # nerv.disko.lvm.persistSize        = "20G"; # /persist LV size
    };

  in {
    nixosModules = {
      # Aggregates system + services + home — the primary host flake entry point.
      default  = import ./modules;
      # Granular exports for hosts that only need a subset.
      system   = import ./modules/system;
      services = import ./modules/services;
      home     = import ./home;
    };

    nixosConfigurations = {
      # Desktop/laptop — openssh, audio, bluetooth, printing, BTRFS impermanence.
      host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          self.nixosModules.default
          host
          ./hosts/configuration.nix
        ];
      };
    };
  };
}
