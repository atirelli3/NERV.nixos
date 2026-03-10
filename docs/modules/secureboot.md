# Module: Secure Boot

**File:** `modules/system/secureboot.nix`

Lanzaboote Secure Boot with automatic TPM2 LUKS binding. Disabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.secureboot.enable` | `bool` | `false` | Enable Lanzaboote + TPM2 auto-unlock. Requires two-boot setup sequence. |

---

## Requirements

- System must be installed and booting correctly before enabling
- UEFI firmware must support Secure Boot Setup Mode
- TPM2 chip required for automatic LUKS unlocking

---

## How it works

### Import order dependency

`secureboot.nix` must be the **last import** in `modules/system/default.nix`. It sets `boot.loader.systemd-boot.enable = lib.mkForce false` to override the `true` set in `boot.nix`. Lanzaboote replaces systemd-boot as the bootloader.

### Two-boot enrollment sequence

**Boot 1 — Key enrollment (Setup Mode):**

`secureboot-enroll-keys.service` runs as a one-shot systemd service:
1. Checks if `/var/lib/secureboot-keys-enrolled` sentinel exists — if yes, exits immediately (idempotent)
2. Detects Setup Mode via `sbctl status`
3. Runs `sbctl enroll-keys --microsoft` (enrolls NERV keys + Microsoft CA for hardware compatibility)
4. Writes `/var/lib/secureboot-keys-enrolled`
5. Triggers `systemctl reboot`

**Boot 2 — TPM2 binding (Secure Boot enforcing):**

`secureboot-enroll-tpm2.service` runs as a one-shot systemd service:
1. Checks if `/var/lib/secureboot-setup-done` sentinel exists — if yes, exits immediately (idempotent)
2. Verifies Secure Boot is enforcing via `sbctl status`
3. Runs `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/disk/by-label/NIXLUKS`
   - PCR 0: Platform firmware (UEFI code)
   - PCR 7: Secure Boot state (tracks the policy — keys, mode)
4. Writes `/var/lib/secureboot-setup-done`

**All subsequent boots:** TPM2 automatically unlocks LUKS without a passphrase prompt.

---

## Setup procedure

### Step 1 — Enter UEFI Setup Mode

Reboot into UEFI firmware settings and clear all existing Secure Boot keys. The exact menu varies by manufacturer. Look for: "Secure Boot", "Key Management", "Reset to Setup Mode", "Clear Secure Boot Keys".

### Step 2 — Enable in configuration

```nix
# hosts/configuration.nix
nerv.secureboot.enable = true;
```

### Step 3 — Rebuild and reboot twice

```bash
sudo nixos-rebuild switch --flake /etc/nixos#host
sudo reboot
# Boot 1: keys enrolled, machine reboots automatically
# Boot 2: LUKS bound to TPM2
```

### Step 4 — Verify

```bash
sbctl status   # Secure Boot: enabled ✓, Setup Mode: disabled ✓
sbctl verify   # all boot files should show ✓ signed
```

---

## Key persistence

Secure Boot keys are stored in `/var/lib/sbctl`. When using impermanence, this path **must be persisted**:

```nix
environment.persistence."/persist".directories = [
  "/var/lib/sbctl"
];
```

NERV emits a `lib.warn` at build time if secureboot is enabled and `/var/lib/sbctl` is not covered by `environment.persistence`.

---

## Re-enrollment after firmware or key changes

If a firmware update changes PCR 0 or 7, LUKS auto-unlock will stop working. Re-bind with the provided helper:

```bash
luks-cryptenroll
```

This runs `systemd-cryptenroll --wipe-slot=tpm2` followed by re-enrollment.

> Only run `luks-cryptenroll` when Secure Boot is active (`sbctl status` shows enabled). Running it without Secure Boot active will wipe the TPM2 slot and require manual LUKS passphrase entry on next boot.

---

## Provided packages

When `nerv.secureboot.enable = true`, these are added to `systemPackages`:

| Package | Use |
|---------|-----|
| `sbctl` | Secure Boot key management |
| `tpm2-tss` | TPM2 software stack |
| `tpm2-tools` | TPM2 command-line tools |

**Helper script:** `luks-cryptenroll` — re-runs `systemd-cryptenroll` to re-bind LUKS to TPM2.

---

## Troubleshooting

**LUKS prompts for passphrase after firmware update:**
A firmware update changed PCR 0 or 7. Run `luks-cryptenroll` to re-bind.

**`sbctl verify` shows unsigned files:**
Some boot files may not be signed. Run `sbctl sign-all` or check `sbctl list-files`.

**Machine stuck at boot after enabling Secure Boot:**
Boot from the NixOS ISO, chroot into the installed system, and disable Secure Boot:
```nix
nerv.secureboot.enable = false;
```
Then rebuild and re-enroll from scratch.
