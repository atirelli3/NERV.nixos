# modules/services/bluetooth.nix
#
# Bluetooth hardware, management tools, PipeWire integration, and OBEX file transfer. Disabled by default.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.bluetooth;
in {
  options.nerv.bluetooth.enable = lib.mkEnableOption "Bluetooth hardware and management tools";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          # Shows battery level of connected devices (requires adapter support).
          Experimental = true;
          # Faster reconnect at the cost of slightly higher idle power draw.
          FastConnectable = true;
        };
        Policy = {
          # Automatically enable all controllers, including hot-plugged adapters.
          AutoEnable = true;
        };
      };
    };

    # Minimal GUI for pairing and managing devices.
    services.blueman.enable = true;

    # mDNS advertisement for Bluetooth services.
    services.avahi.enable = true;

    # WirePlumber (PipeWire session manager) Bluetooth audio configuration.
    # Placed unconditionally — no effect if PipeWire is not enabled.
    services.pipewire.wireplumber.extraConfig = {
      "10-bluez"."monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;    # SBC-XQ: higher-bitrate variant of the default SBC codec
        "bluez5.enable-msbc"   = true;    # mSBC: wideband speech codec for clearer call audio
        "bluez5.enable-hw-volume" = true; # let the device control its own volume
        # Headset/handsfree roles for call audio (A2DP for music is enabled by default).
        "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      };
      # Keep the high-quality A2DP audio profile when connected; don't downgrade
      # to headset (HSP/HFP) profile just because a call app opened a sink.
      "11-bluetooth-policy"."wireplumber.settings"."bluetooth.autoswitch-to-headset-profile" = false;
    };

    # File transfer from/to mobile devices via OBEX.
    # Accepted files land in ~/Downloads; not all extensions are supported by obexd.
    # Pair and trust the device in blueman first, then initiate the transfer from the phone.
    systemd.user.services.obex.serviceConfig.ExecStart = [
      ""  # clear the default ExecStart before overriding
      "${pkgs.bluez}/libexec/bluetooth/obexd --root=%h/Downloads --auto-accept"
    ];

    # Forward headset media buttons (play/pause/next/prev) to MPRIS-compatible players.
    systemd.user.services.mpris-proxy = {
      description = "Bluetooth headset MPRIS proxy";
      after    = [ "network.target" "sound.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
    };
  };
}
