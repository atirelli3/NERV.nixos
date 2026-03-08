# modules/services/openssh.nix
#
# Purpose  : SSH daemon hardened with endlessh tarpit and fail2ban.
# Options  : nerv.openssh.enable, nerv.openssh.port, nerv.openssh.tarpitPort,
#            nerv.openssh.allowUsers, nerv.openssh.passwordAuth,
#            nerv.openssh.kbdInteractiveAuth
# Defaults : enable = false; port = 2222; tarpitPort = 22; allowUsers = []
#            passwordAuth = false; kbdInteractiveAuth = false
# Override : lib.mkForce on any services.openssh.* or services.fail2ban.* setting.
# Note     : Port 22 is reserved for the endlessh tarpit. Connect with ssh -p <port>.
#            allowUsers guard: empty list means "all users" in sshd — never emit
#            AllowUsers when the list is empty (lib.optionalAttrs guard enforces this).

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.openssh;
in {
  options.nerv.openssh = {
    enable = lib.mkEnableOption "OpenSSH daemon with endlessh tarpit and fail2ban";

    port = lib.mkOption {
      type        = lib.types.port;
      default     = 2222;
      description = "Port the SSH daemon listens on. Port 22 is reserved for the endlessh tarpit.";
      example     = 2222;
    };

    tarpitPort = lib.mkOption {
      type        = lib.types.port;
      default     = 22;
      description = "Port endlessh binds to (the tarpit). Must differ from port.";
      example     = 22;
    };

    allowUsers = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Restrict SSH access to these users. Empty list (default) allows all users. Uses sshd AllowUsers — do not set an empty list in sshd as it would lock everyone out; this module guards against that.";
      example     = [ "alice" "bob" ];
    };

    passwordAuth = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Allow password authentication. Disabled by default (key-based auth only).";
    };

    kbdInteractiveAuth = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Allow keyboard-interactive authentication.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.tarpitPort != cfg.port;
      message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
    }];

    # SSH daemon on a non-standard port so port 22 is free for the tarpit (endlessh).
    # Connect with: ssh -p <port> user@host
    services.openssh = {
      enable       = true;
      ports        = [ cfg.port ];
      openFirewall = true; # fail2ban handles IP banning; the firewall must still be open for the port to accept connections
      settings = {
        PasswordAuthentication        = cfg.passwordAuth;
        KbdInteractiveAuthentication  = cfg.kbdInteractiveAuth;
        PermitRootLogin               = "no"; # never allow direct root login; use a normal user + sudo
      } // lib.optionalAttrs (cfg.allowUsers != []) {
        # Only emit AllowUsers when non-empty — an empty AllowUsers in sshd means "allow nobody".
        AllowUsers = cfg.allowUsers;
      };
    };

    # Tarpit on tarpitPort: sends an infinitely slow SSH banner to waste bot connections.
    services.endlessh = {
      enable       = true;
      port         = cfg.tarpitPort;
      openFirewall = true;
    };

    # Rate-limits and bans offending IPs. Hardcoded opinionated defaults.
    # Host flakes can override individual settings with lib.mkForce if needed.
    services.fail2ban = {
      enable    = true;
      maxretry  = 5;
      ignoreIP  = [
        # Private subnets — never ban your own LAN.
        "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16"
      ];
      bantime   = "24h";
      bantime-increment = {
        enable       = true;   # Exponentially lengthen ban on repeat offenders.
        maxtime      = "168h"; # Cap at 1 week.
        overalljails = true;   # Aggregate violations across all jails.
      };
      jails.sshd.settings = {
        mode     = "aggressive"; # Also catches probes for invalid users and non-existent home dirs.
        maxretry = 3;            # Ban after 3 failures (overrides global 5).
        findtime = 600;          # Within a 10-minute window.
        port     = toString cfg.port; # types.port is int; fail2ban setting expects a string.
      };
    };
  };
}
