# modules/system/identity.nix
#
# Machine hostname, locale, and primary user declaration.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv;
in {
  options.nerv.hostname = lib.mkOption {
    type        = lib.types.str;
    description = "Machine hostname. Sets networking.hostName. Required — no default.";
    example     = "nixos-workstation";
  };

  options.nerv.locale = {
    timeZone = lib.mkOption {
      type        = lib.types.str;
      default     = "UTC";
      description = "System time zone. See 'timedatectl list-timezones'.";
      example     = "Europe/Rome";
    };

    defaultLocale = lib.mkOption {
      type        = lib.types.str;
      default     = "en_US.UTF-8";
      description = "Default system locale for LC_* variables.";
      example     = "it_IT.UTF-8";
    };

    keyMap = lib.mkOption {
      type        = lib.types.str;
      default     = "us";
      description = "Console keymap. Run 'localectl list-keymaps' for available values.";
      example     = "us-acentos";
    };
  };

  options.nerv.primaryUser = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = "Primary system users. Each gets wheel+networkmanager groups wired automatically. If nerv.zsh.enable is true, shell is set to pkgs.zsh for each listed user.";
    example     = [ "demon0" ];
  };

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = config.nerv.hostname != "";
        message   = "nerv.hostname must not be empty string.";
      }];
      networking.hostName    = config.nerv.hostname;
      time.timeZone          = config.nerv.locale.timeZone;
      i18n.defaultLocale     = config.nerv.locale.defaultLocale;
      console.keyMap         = config.nerv.locale.keyMap;
      # Terminus gives the best unicode coverage in TTY (PSF format).
      # Override with lib.mkForce if a different font is preferred.
      console.font           = "ter-v18n";
      console.packages       = [ pkgs.terminus_font ];
    }

    (lib.mkIf (config.nerv.primaryUser != []) {
      users.users = lib.genAttrs config.nerv.primaryUser (_name: {
        extraGroups = [ "wheel" "networkmanager" ];
      } // lib.optionalAttrs config.nerv.zsh.enable {
        shell = pkgs.zsh;
      });
    })
  ];
}
