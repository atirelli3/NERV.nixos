# modules/system/hardware.nix
#
# CPU microcode, GPU drivers, and hardware-agnostic firmware. cpu defaults to "other"; gpu defaults to "none".

{ config, lib, pkgs, ... }:
let
  cfg = config.nerv.hardware;
in {
  options.nerv.hardware = {
    cpu = lib.mkOption {
      type        = lib.types.enum [ "amd" "intel" "other" ];
      default     = "other";
      description = "CPU vendor. Selects microcode package and IOMMU kernel params. Use \"other\" for CPUs without vendor-specific microcode support.";
      example     = "amd";
    };
    gpu = lib.mkOption {
      type        = lib.types.enum [ "amd" "nvidia" "intel" "none" ];
      default     = "none";
      description = "GPU driver to enable. \"none\" applies no driver configuration.";
      example     = "amd";
    };
  };

  config = lib.mkMerge [
    # Unconditional — hardware-agnostic firmware and utilities
    {
      # Load firmware blobs for Wi-Fi cards, GPUs, and other peripherals.
      # Requires nixpkgs.config.allowUnfree = true (set in nix.nix).
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware             = true; # broad compatibility for Wi-Fi, BT, GPUs
      # Firmware updates for supported devices (laptops, drives, peripherals) via LVFS.
      # Run updates with: fwupdmgr refresh && fwupdmgr upgrade
      services.fwupd.enable                  = true;
      # Periodic SSD TRIM to maintain performance and longevity on SSDs.
      # LUKS with allowDiscards = true (set in configuration.nix) is required for TRIM on encrypted drives.
      services.fstrim = {
        enable   = true;
        interval = "weekly"; # SSD TRIM; LUKS allowDiscards must be set in boot config
      };
    }

    # CPU microcode + IOMMU kernel params
    (lib.mkIf (cfg.cpu == "amd") {
      hardware.cpu.amd.updateMicrocode = true;
      boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
    })
    (lib.mkIf (cfg.cpu == "intel") {
      hardware.cpu.intel.updateMicrocode = true;
      boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
    })

    # GPU drivers
    (lib.mkIf (cfg.gpu == "nvidia") {
      # Open kernel module — Turing+ (RTX 20xx+) only.
      # Maxwell/Pascal: override with hardware.nvidia.open = lib.mkForce false;
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open           = true;
    })
    (lib.mkIf (cfg.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
    })
    (lib.mkIf (cfg.gpu == "intel") {
      services.xserver.videoDrivers = [ "intel" ];
    })
    # cfg.gpu == "none": no GPU config emitted
  ];
}
