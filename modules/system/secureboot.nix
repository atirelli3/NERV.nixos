# modules/system/secureboot.nix
#
# Lanzaboote Secure Boot and TPM2 LUKS auto-unlock. Disabled by default. Must be last import in system/default.nix.

{ config, lib, pkgs, ... }:
let
  cfg = config.nerv.secureboot;
in {
  options.nerv.secureboot = {
    enable = lib.mkEnableOption "Lanzaboote Secure Boot and TPM2 LUKS auto-unlock";
  };

  config = lib.mkIf cfg.enable {
    # Lanzaboote supersedes systemd-boot; the NixOS-generated entry must be disabled.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    # Configure the initrd LUKS unlock to use TPM2 bound to PCRs 0+7.
    boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [ "tpm2-device=auto" "tpm2-pcrs=0+7" ];
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    # TPM2 — required for LUKS auto-unlock sealed to Secure Boot state (PCR 7).
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    # First-boot setup runs across two reboots.
    # PCR 7 measures the Secure Boot policy; enrolling keys changes it on the NEXT boot.
    # Binding LUKS to TPM2 in the same boot as key enrollment would capture the wrong
    # PCR 7 value, causing TPM2 to refuse auto-unlock. The split ensures TPM2 is bound
    # when PCR 7 already reflects the active Secure Boot state.
    #   Boot 1 — enroll Secure Boot keys → automatic reboot
    #   Boot 2 — bind LUKS to TPM2 (PCR 7 now correct)

    # Boot 1: enroll Secure Boot keys, then reboot automatically.
    systemd.services.secureboot-enroll-keys = {
      description = "First boot [1/2]: enroll Secure Boot keys";
      wantedBy = [ "multi-user.target" ];
      after    = [ "multi-user.target" ];
      path     = [ pkgs.sbctl pkgs.systemd ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = "root";
      };

      script = ''
        if [ -f /var/lib/secureboot-keys-enrolled ]; then
          echo "secureboot [1/2]: already done, skipping"
          exit 0
        fi

        if ! ${pkgs.sbctl}/bin/sbctl status | grep -q "Setup Mode.*Enabled"; then
          echo "secureboot [1/2]: not in Setup Mode, skipping"
          exit 0
        fi

        echo "secureboot [1/2]: enrolling Secure Boot keys..."
        ${pkgs.sbctl}/bin/sbctl enroll-keys --microsoft

        touch /var/lib/secureboot-keys-enrolled
        echo "secureboot [1/2]: keys enrolled — rebooting to activate Secure Boot..."
        systemctl reboot
      '';
    };

    # Boot 2: bind LUKS to TPM2 now that PCR 7 reflects active Secure Boot.
    systemd.services.secureboot-enroll-tpm2 = {
      description = "First boot [2/2]: bind LUKS to TPM2";
      wantedBy = [ "multi-user.target" ];
      after    = [ "multi-user.target" "secureboot-enroll-keys.service" ];
      path     = [ pkgs.sbctl pkgs.systemd pkgs.tpm2-tss ];

      serviceConfig = {
        Type            = "oneshot";
        RemainAfterExit = true;
        User            = "root";
      };

      script = let
        luksDevice01 = "NIXLUKS";  # must match disko-configuration.nix and boot.nix
      in ''
        # Step 1 must have completed first
        if [ ! -f /var/lib/secureboot-keys-enrolled ]; then
          echo "secureboot [2/2]: step 1 not done yet, skipping"
          exit 0
        fi

        if [ -f /var/lib/secureboot-setup-done ]; then
          echo "secureboot [2/2]: already done, skipping"
          exit 0
        fi

        # Verify Secure Boot is now enforcing before binding PCR 7
        if ! ${pkgs.sbctl}/bin/sbctl status | grep -q "Secure Boot.*Enabled"; then
          echo "secureboot [2/2]: Secure Boot not active yet, will retry next boot"
          exit 0
        fi

        echo "secureboot [2/2]: binding LUKS to TPM2 (PCR 7 now reflects active Secure Boot)..."
        if ! ${pkgs.systemd}/bin/systemd-cryptenroll /dev/disk/by-label/${luksDevice01} | grep -q "tpm2"; then  # must match disko-configuration.nix and boot.nix
          ${pkgs.systemd}/bin/systemd-cryptenroll \
            --wipe-slot=tpm2   \
            --tpm2-device=auto \
            --tpm2-pcrs=0+7    \
            /dev/disk/by-label/${luksDevice01}  # must match disko-configuration.nix and boot.nix
        else
          echo "secureboot [2/2]: TPM2 slot already enrolled, skipping"
        fi

        touch /var/lib/secureboot-setup-done
        echo "secureboot [2/2]: done — LUKS will auto-unlock via TPM2 from next boot"
      '';
    };

    # Re-enrollment helper and Secure Boot / TPM2 management tools.
    environment.systemPackages = let
      luks-cryptenroll = pkgs.writeTextFile {
        name = "luks-cryptenroll";
        destination = "/bin/luks-cryptenroll";
        executable = true;

        # To enroll additional LUKS devices, extend the script like so:
        # text = let
        #   ...
        #   luksDevice02 = "BEEGLUKS01";
        #   luksDevice03 = "BEEGLUKS02";
        # in ''
        #   ...
        #   sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 /dev/disk/by-label/${luksDevice02}
        #   sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 /dev/disk/by-label/${luksDevice03}
        # '';

        text = let
          luksDevice01 = "NIXLUKS";  # must match disko-configuration.nix and boot.nix
        in ''
          sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 /dev/disk/by-label/${luksDevice01}
        '';
      };
    in [
      luks-cryptenroll
      pkgs.sbctl
      pkgs.tpm2-tss
      pkgs.tpm2-tools
    ];
  };
}
