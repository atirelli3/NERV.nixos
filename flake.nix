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
    # hostProfile — classic desktop/laptop configuration.
    # openssh, audio, bluetooth, printing enabled. Minimal impermanence (/tmp, /var/tmp as tmpfs).
    # Enable nerv.secureboot.enable = true after running sbctl enroll-keys on the target machine.
    hostProfile = {
      nerv.openssh.enable       = true;
      nerv.audio.enable         = true;
      nerv.bluetooth.enable     = true;
      nerv.printing.enable      = true;
      nerv.secureboot.enable    = false;
      nerv.impermanence.enable  = true;
      nerv.impermanence.mode    = "minimal";
      nerv.zsh.enable           = true;
      nerv.home.enable          = true;
    };

    # serverProfile — headless server configuration.
    # openssh only. Full impermanence: / is tmpfs, state persisted to /persist.
    # Requires impermanence.nixosModules.impermanence in modules list (see nixosConfigurations.server).
    serverProfile = {
      nerv.openssh.enable       = true;
      nerv.audio.enable         = false;
      nerv.bluetooth.enable     = false;
      nerv.printing.enable      = false;
      nerv.secureboot.enable    = false;
      nerv.impermanence.enable  = true;
      nerv.impermanence.mode    = "full";
      nerv.zsh.enable           = true;
      nerv.home.enable          = false;
    };

    # vmProfile — virtual machine configuration.
    # Similar to host but without bluetooth or printing. No secureboot (VMs lack TPM2).
    vmProfile = {
      nerv.openssh.enable       = true;
      nerv.audio.enable         = true;
      nerv.bluetooth.enable     = false;
      nerv.printing.enable      = false;
      nerv.secureboot.enable    = false;
      nerv.impermanence.enable  = true;
      nerv.impermanence.mode    = "minimal";
      nerv.zsh.enable           = true;
      nerv.home.enable          = true;
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
      # Desktop/laptop profile — openssh, audio, bluetooth, printing, minimal impermanence.
      host = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          impermanence.nixosModules.impermanence
          self.nixosModules.default
          hostProfile
          ./hosts/configuration.nix
          disko.nixosModules.disko
          ./hosts/disko-host.nix
        ];
      };

      # Headless server profile — openssh only, full impermanence (/ tmpfs, /persist state).
      server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          impermanence.nixosModules.impermanence  # required for environment.persistence (mode = "full")
          self.nixosModules.default
          serverProfile
          ./hosts/configuration.nix
          disko.nixosModules.disko
          ./hosts/disko-configuration.nix
        ];
      };

      # VM profile — host-like without bluetooth/printing, secureboot disabled.
      vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          impermanence.nixosModules.impermanence
          self.nixosModules.default
          vmProfile
          ./hosts/configuration.nix
          disko.nixosModules.disko
          ./hosts/disko-host.nix
        ];
      };
    };
  };
}
