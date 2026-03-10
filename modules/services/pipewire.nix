# modules/services/pipewire.nix
#
# PipeWire audio stack with ALSA, PulseAudio compat, and AirPlay sink. Disabled by default.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.audio;
in {
  options.nerv.audio.enable = lib.mkEnableOption "PipeWire audio stack";

  config = lib.mkIf cfg.enable {
    # Allows PipeWire to acquire realtime scheduling priority.
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true; # needed for 32-bit apps (e.g. Steam, Wine)
      pulse.enable = true;      # PulseAudio compatibility layer
      # jack.enable = true;     # uncomment to enable JACK compatibility

      raopOpenFirewall = true;  # opens UDP 6001-6002 for AirPlay sink discovery

      extraConfig.pipewire = {
        # Silence the X11 urgency-hint bell (fired by some shell prompts).
        "99-silent-bell.conf"."context.properties"."module.x11.bell" = false;

        # AirPlay sink: stream audio to RAOP receivers on the network.
        "10-airplay"."context.modules" = [{
          name = "libpipewire-module-raop-discover";
          # args."raop.latency.ms" = 500; # increase if you get dropouts
        }];

        # Reduced latency for general desktop use.
        # quantum = buffer size in samples; lower = less latency but more CPU load.
        # 1024/48000 ≈ 21ms — a safe default. For audio production go as low as 64 or 32.
        # If you get crackling/dropouts, increase quantum or enable a realtime kernel.
        "92-low-latency"."context.properties" = {
          "default.clock.rate"        = 48000;
          "default.clock.quantum"     = 1024;
          "default.clock.min-quantum" = 32;    # apps can request lower if needed
          "default.clock.max-quantum" = 8192;  # apps can request higher for efficiency
        };
      };

      # Match PulseAudio backend to the same latency budget.
      extraConfig.pipewire-pulse."92-low-latency" = {
        "pulse.properties" = {
          "pulse.min.req"     = "1024/48000";
          "pulse.default.req" = "1024/48000";
          "pulse.max.req"     = "1024/48000";
          "pulse.min.quantum" = "1024/48000";
          "pulse.max.quantum" = "1024/48000";
        };
        "stream.properties" = {
          "node.latency"     = "1024/48000";
          "resample.quality" = 4; # 0 = fastest, 10 = best quality
        };
      };
    };

    # Graphical PipeWire tools (GTK4 / libadwaita).
    #   pwvucontrol — per-app volume control and device management (replaces pavucontrol)
    #   helvum      — patchbay for routing streams between sources and sinks
    environment.systemPackages = with pkgs; [
      pwvucontrol
      helvum
    ];
  };
}
