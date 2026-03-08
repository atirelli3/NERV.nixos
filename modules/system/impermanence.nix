# modules/system/impermanence.nix
#
# Purpose  : Selective per-directory tmpfs mounts — /tmp, /var/tmp, and user volatile dirs.
#            Full mode: / as tmpfs + environment.persistence for server use.
# Model    : minimal — Root (/) stays on disk; specific dirs mounted as tmpfs at boot.
#            full    — Root (/) is tmpfs; /persist holds system state via environment.persistence.
#            The upstream nixos-community/impermanence module is used only in full mode.
# Options  : nerv.impermanence.enable, mode, persistPath, extraDirs, users
# Defaults : enable = false; mode = minimal; persistPath = "/persist"; extraDirs = []; users = {}
# Override : lib.mkForce on any fileSystems.* entry, or disable impermanence entirely.
# Note     : full mode requires impermanence.nixosModules.impermanence in the host's modules list.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.impermanence;

  # Build fileSystems attrset from extraDirs — evaluated lazily as a let binding,
  # not inside a lib.mkMerge list (pushDownProperties evaluates mkMerge contents
  # eagerly, which would force cfg.* before the mkIf condition is checked → cycle).
  extraDirFileSystems = builtins.listToAttrs (map (path: {
    name  = path;
    value = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=25%" "nosuid" "nodev" ]; };
  }) cfg.extraDirs);

  # Build fileSystems attrset from per-user path/size mappings.
  userFileSystems = lib.foldlAttrs (acc: _user: pathMap:
    acc // builtins.listToAttrs (lib.mapAttrsToList (path: size: {
      name  = path;
      value = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=${size}" "nosuid" "nodev" ]; };
    }) pathMap)
  ) {} cfg.users;

  # Build systemd.tmpfiles.rules entries for per-user mount points.
  # Pre-creates directories so tmpfs mounts don't fail on absent paths at boot.
  userTmpfilesRules = lib.concatLists (lib.mapAttrsToList (user: pathMap:
    lib.mapAttrsToList (path: _: "d ${path} 0755 ${user} users -") pathMap
  ) cfg.users);
in {
  options.nerv.impermanence = {
    enable = lib.mkEnableOption "selective per-directory tmpfs impermanence";

    mode = lib.mkOption {
      type        = lib.types.enum [ "minimal" "full" ];
      default     = "minimal";
      description = ''
        Impermanence mode.
          minimal — /tmp and /var/tmp as tmpfs; root stays on disk. Default for desktop/VM profiles.
          full    — / as tmpfs (resets on reboot); /persist holds system state via
                    environment.persistence. Requires impermanence.nixosModules.impermanence
                    in the host nixosConfigurations modules list. For server profiles.
      '';
    };

    persistPath = lib.mkOption {
      type        = lib.types.str;
      default     = "/persist";
      description = "Persistence base path. Used as the environment.persistence key in full mode.";
    };

    extraDirs = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Additional absolute system paths to mount as tmpfs. Additive to the defaults (/tmp, /var/tmp).";
      example     = [ "/var/cache/app" ];
    };

    users = lib.mkOption {
      type        = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default     = {};
      description = "Per-user tmpfs mounts. Keys are usernames; values map absolute path to size string (e.g. \"4G\", \"25%\").";
      example     = { demon0 = { "/home/demon0/Videos" = "8G"; }; };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # IMPL-02: sbctl safety assertion — only active when secureboot is also enabled.
      assertions = lib.optional config.nerv.secureboot.enable {
        assertion =
          let
            allPaths = cfg.extraDirs
              ++ lib.concatLists (lib.mapAttrsToList (_user: pathMap: lib.attrNames pathMap) cfg.users);
            isSbctlPath = p: p == "/var/lib/sbctl"
              || lib.hasPrefix "/var/lib/sbctl" p
              || lib.hasPrefix p "/var/lib/sbctl";
          in
            !(lib.any isSbctlPath allPaths);
        message = "nerv: /var/lib/sbctl is in impermanence tmpfs paths — this would wipe Secure Boot keys on every reboot. Remove it from impermanence configuration.";
      };

      # Default system tmpfs mounts plus any configured extraDirs and user paths.
      # Merged via // (attrset union) so keys are static from pushDownProperties' view.
      fileSystems = {
        "/tmp" = {
          device  = "tmpfs";
          fsType  = "tmpfs";
          options = [ "size=25%" "mode=1777" "nosuid" "nodev" ];
        };
        "/var/tmp" = {
          device  = "tmpfs";
          fsType  = "tmpfs";
          options = [ "size=25%" "mode=1777" "nosuid" "nodev" ];
        };
      } // extraDirFileSystems // userFileSystems;

      systemd.tmpfiles.rules = userTmpfilesRules;
    }

    (lib.mkIf (cfg.mode == "full") {
      # / as tmpfs — reset on every reboot (Nix store on /nix, state on /persist)
      fileSystems."/" = {
        device  = "none";
        fsType  = "tmpfs";
        options = [ "defaults" "size=2G" "mode=755" ];
      };

      # /persist must be available before systemd-tmpfiles and impermanence bind mounts
      fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;

      # environment.persistence from nixos-community/impermanence module
      # Requires impermanence.nixosModules.impermanence in nixosConfigurations modules list
      environment.persistence."${cfg.persistPath}" = {
        hideMounts = true;
        directories = [
          "/var/log"          # systemd journal, syslog
          "/var/lib/nixos"    # nixos user/group ID allocations (mutableUsers state)
          "/var/lib/systemd"  # systemd coredumps, timers, unit state
          "/etc/nixos"        # NERV.nixos repo — user clones here, must survive reboots
        ];
        files = [
          "/etc/machine-id"                    # stable machine identity (journald, systemd)
          "/etc/ssh/ssh_host_ed25519_key"      # SSH host identity — must survive reboots
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };
    })
  ]);
}
