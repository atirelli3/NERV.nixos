# modules/services/printing.nix
#
# CUPS printing daemon with network printer discovery via Avahi/mDNS. Disabled by default.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.printing;
in {
  options.nerv.printing.enable = lib.mkEnableOption "CUPS printing daemon with network printer discovery";

  config = lib.mkIf cfg.enable {
    # CUPS printing daemon.
    services.printing = {
      enable = true;
      # Add drivers for your printer brand. Common options:
      #   pkgs.gutenprint      — broad multi-brand support
      #   pkgs.gutenprintBin   — binary drivers for some Epson/Canon models
      #   pkgs.hplip           — HP printers
      #   pkgs.brlaser         — Brother laser printers
      drivers = with pkgs; [
        gutenprint
      ];
    };

    # Network printer discovery via mDNS (.local hostnames).
    # avahi.enable is owned here so printing works independently of nerv.audio.
    services.avahi = {
      enable   = true;
      nssmdns4 = true;
    };

    # Declarative printer definition (optional — remove if you prefer CUPS web UI).
    # After adding, apply with: nixos-rebuild switch, then cups will have it pre-configured.
    # hardware.printers.ensurePrinters = [{
    #   name        = "MyPrinter";
    #   location    = "Home";
    #   deviceUri   = "ipp://printer.local/ipp/print"; # or usb://... for USB
    #   model       = "drv:///sample.drv/generic.ppd"; # or path to PPD file
    #   ppdOptions.PageSize = "A4";
    # }];
    # hardware.printers.ensureDefaultPrinter = "MyPrinter";
  };
}
