# modules/system/impermanence.nix
#
# Selective persistence via environment.persistence bind-mounts. btrfs mode for desktop; full mode for server.
# Profiles : host mode=btrfs | server mode=full

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
      type        = lib.types.enum [ "btrfs" "full" ];
      description = ''
        Impermanence mode.
          btrfs — Root stays on BTRFS @; rollback service resets @ on each boot.
                  /persist (@persist subvolume) holds state via environment.persistence.
                  For desktop/laptop profiles. Requires nerv.disko.layout = "btrfs".
          full  — / as tmpfs (resets on reboot); /persist holds system state via
                  environment.persistence. For server profiles.
                  Requires impermanence.nixosModules.impermanence in nixosConfigurations modules list.
        Intentionally no default — forces explicit declaration per host;
        consistent with nerv.disko.layout and nerv.hostname.
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
      description = "Additional absolute system paths to mount as tmpfs.";
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

      # extraDirs and per-user tmpfs mounts — additive; no default system paths.
      # Merged via // (attrset union) so keys are static from pushDownProperties' view.
      fileSystems = extraDirFileSystems // userFileSystems;

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

    (lib.mkIf (cfg.mode == "btrfs") {
      # /persist must be available before impermanence bind mounts execute in stage 2.
      # disko v1.13.0 does not support neededForBoot on subvolume mounts (issues #192, #594
      # closed as "use fileSystems directly"); this override is the canonical approach.
      fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;

      # environment.persistence — bind mounts from /persist for desktop/laptop BTRFS mode.
      # Root is reset to @root-blank on every boot (Phase 10 rollback service), so /var/lib
      # is empty at stage 2 activation — no bind-over-content risk.
      # Requires impermanence.nixosModules.impermanence in nixosConfigurations modules list.
      environment.persistence."${cfg.persistPath}" = {
        hideMounts = true;
        directories = [
          "/var/lib"   # all service state: uid/gid (nixos), timers (systemd), sbctl, BT, NM, cups...
          "/etc/nixos" # NERV.nixos repo — user clones here, must survive rollback
          # NOTE: /var/log intentionally omitted — persisted by @log BTRFS subvolume (disko.nix).
          #       Adding it here would create a double-mount conflict at stage-2 activation.
        ];
        files = [
          "/etc/machine-id"                    # stable machine identity (journald, systemd)
          "/etc/ssh/ssh_host_ed25519_key"      # SSH host identity — must survive rollback
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };

      # Belt-and-suspenders: /var/lib as a single broad entry already covers /var/lib/sbctl.
      # This warning fires only if someone strips the persistence list and forgets sbctl.
      # Using lib.warn (not assertion) — preserves nix flake check during multi-step migrations;
      # missing sbctl persistence loses keys on next rollback but is recoverable via re-enrollment,
      # unlike the IMPL-02 scenario (tmpfs wipe) which uses a hard assertion.
      warnings =
        let
          persistDirs = [ "/var/lib" "/etc/nixos" ];
          sbctlCovered = lib.any
            (d: d == "/var/lib" || d == "/var/lib/sbctl" || lib.hasPrefix "/var/lib/sbctl" d)
            persistDirs;
        in
          lib.optionals (config.nerv.secureboot.enable && !sbctlCovered)
            [ "nerv: secureboot is enabled but /var/lib/sbctl is not covered by environment.persistence in btrfs mode — sbctl keys will be lost on rollback." ];
    })
  ]);
}
