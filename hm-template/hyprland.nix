# hm-template/hyprland.nix
#
# Hyprland window manager via Home Manager.

{ config, lib, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      # ── Monitor layout ────────────────────────────────────────────────────
      # monitor = "eDP-1,1920x1080@60,0x0,1";   # laptop screen example
      # monitor = "DP-1,2560x1440@144,0x0,1";   # external monitor example

      # ── Autostart ─────────────────────────────────────────────────────────
      exec-once = [
        # "waybar"
        # "swww-daemon"
        # "dunst"
      ];

      # ── Input ─────────────────────────────────────────────────────────────
      input = {
        kb_layout    = "us";             # change to your keyboard layout
        follow_mouse = 1;
        touchpad.natural_scroll = true;
      };

      # ── General ───────────────────────────────────────────────────────────
      general = {
        gaps_in     = 5;
        gaps_out    = 10;
        border_size = 2;
      };

      # ── Decorations ───────────────────────────────────────────────────────
      decoration = {
        rounding = 8;
        # blur.enabled = true;
      };

      # ── Keybinds (mod = Super) ─────────────────────────────────────────────
      "$mod" = "SUPER";
      bind = [
        "$mod, Return, exec, ghostty"
        "$mod, D,      exec, rofi -show drun"
        "$mod, Q,      killactive"
        "$mod, F,      fullscreen"
        "$mod, 1,      workspace, 1"
        "$mod, 2,      workspace, 2"
        "$mod, 3,      workspace, 3"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
      ];
    };
  };
}
