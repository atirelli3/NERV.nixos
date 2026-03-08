# Coding Conventions

**Analysis Date:** 2026-03-06

## Language

This is a pure **Nix** configuration codebase. All files use the `.nix` extension and the Nix expression language. There are no TypeScript, Python, or other general-purpose languages. Conventions below are Nix-specific.

## File Header Pattern

Every module file opens with the standard NixOS module argument destructure, followed by a blank line, then the attribute set body:

```nix
{ config, lib, pkgs, ... }:

{
  # content
}
```

Files that require `let` bindings place them between the argument line and the opening `{`:

```nix
{ config, lib, pkgs, ... }:

let
  myDerivation = pkgs.writeTextFile { ... };
in

{
  # content
}
```

See `modules/secureboot.nix` and `.template/secureboot-configuration.nix` for examples.

Flake files (`base/flake.nix`, `.template/flake.nix`, `.template/flake2.nix`) use the raw attribute set form without module arguments, as required by the flake schema.

## Naming Patterns

**Files:**
- Module files: `kebab-case.nix` — e.g., `openssh.nix`, `secureboot.nix`, `pipewire.nix`
- Configuration files: `configuration.nix`, `disko-configuration.nix` (fixed names per NixOS convention)
- Flake entry points: `flake.nix`

**NixOS option paths:** Follow upstream NixOS naming exactly — `services.openssh`, `boot.lanzaboote`, `security.apparmor`. No custom naming layer exists.

**Attribute keys in sets:** Use camelCase for NixOS-standard attributes (`allowDiscards`, `extraFormatArgs`, `powerOnBoot`). Use SCREAMING_SNAKE_CASE for disk labels as they appear in filesystem identifiers: `NIXBOOT`, `NIXROOT`, `NIXLUKS`, `NIXSWAP`, `NIXSTORE`, `NIXPERSIST`, `NIXHOME`.

**Let-bound variables:** camelCase — `luksDevice01`, `luks-cryptenroll`.

**systemd service names:** `kebab-case` strings — `"secureboot-enroll-keys"`, `"aide-check"`.

## Attribute Set Style

**Prefer grouped attribute sets over flat dot-notation when multiple sub-keys are set:**

```nix
# Preferred — grouped
services.openssh = {
  enable = true;
  ports = [ 2222 ];
  openFirewall = true;
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no";
  };
};

# Avoid — flat repetition
services.openssh.enable = true;
services.openssh.ports = [ 2222 ];
```

Exception: single-option settings use dot-notation inline — `services.avahi.nssmdns4 = true;` when only one key is set.

**Alignment:** Multi-key attribute sets within a block are visually aligned at the `=` sign when keys are short and related:

```nix
serviceConfig = {
  Type            = "oneshot";
  RemainAfterExit = true;
  User            = "root";
};
```

See `modules/security.nix` (lines 96–104) and `modules/secureboot.nix` (lines 60–64) for this pattern.

## Comment Style

**Inline comments** use `#` at end of line with two spaces before `#`:

```nix
alsa.support32Bit = true;  # needed for 32-bit apps (e.g. Steam, Wine)
```

**Block comments** precede the option they describe. Short rationale goes on the line immediately before:

```nix
# Prevent writing to the kernel image at runtime (blocks /dev/mem abuse).
security.protectKernelImage = true;
```

**Multi-line explanations** use consecutive `#` lines, never `/* */` block comments:

```nix
# First-boot setup runs across two reboots.
# PCR 7 measures the Secure Boot policy; enrolling keys changes it on the NEXT boot.
# Binding LUKS to TPM2 in the same boot as key enrollment would capture the wrong
# PCR 7 value, causing TPM2 to refuse auto-unlock.
```

**Section dividers** appear in monolithic `configuration.nix` templates only (not in dedicated module files). They use `# ===` banners with a label in caps:

```nix
# ============================================================
# SECURITY
# ============================================================
```

Dedicated module files (under `modules/`) do NOT use section banners — each file is already scoped to one concern.

**Commented-out code blocks** are used to provide opt-in examples or alternatives. They always include a note explaining when to uncomment:

```nix
# Option A: inline the key directly
#   users.users."myUser".openssh.authorizedKeys.keys = [
#     "ssh-ed25519 AAAA... user@host"
#   ];
#
# Option B: point to an authorized_keys file (e.g. ./ssh/authorized_keys)
```

See `modules/openssh.nix` (lines 18–32) and `modules/pipewire.nix` (line 15).

## Indentation and Formatting

- **2-space indentation** throughout all `.nix` files.
- Closing braces `}`, `]`, `)` align with the opening statement's indentation level.
- List items on separate lines when the list has more than 2 elements:

```nix
modules = [
  ./configuration.nix
  lanzaboote.nixosModules.lanzaboote
  ../modules/secureboot.nix
];
```

- Short two-element lists may fit on one line:

```nix
extraGroups = [ "wheel" "networkmanager" ];
```

## lib.mkForce Usage

`lib.mkForce` is used explicitly when a module must override a value that another module sets (specifically for `fileSystems` overriding Disko-generated mounts, and for disabling `systemd-boot` when lanzaboote takes over):

```nix
# lib.mkForce overrides the Disko-generated mounts — keep labels in sync with disko-configuration.nix.
fileSystems."/" = lib.mkForce { ... };
boot.loader.systemd-boot.enable = lib.mkForce false;
```

Always accompany `lib.mkForce` with a comment explaining why the override is necessary. See `base/configuration.nix` (lines 13–24) and `modules/secureboot.nix` (line 30).

## with pkgs Pattern

`with pkgs; [ ... ]` is used for `environment.systemPackages` and `fonts.packages` lists:

```nix
environment.systemPackages = with pkgs; [
  lynis
  aide
];
```

Direct `pkgs.` prefixing is used in `path = [ pkgs.sbctl pkgs.systemd ]` and similar service `path` attributes, where clarity about exact packages is preferred.

## Placeholder Conventions

Unresolved site-specific values are marked with uppercase placeholder strings and a comment:

```nix
device = "/dev/DISK";  # replace with actual disk, e.g. "/dev/nvme0n1"
size = "SIZE_RAM * 2"; # placeholder — replace with e.g. "16G" (2× RAM)
AllowUsers = [ "myUser" ]; # replace with your actual username
```

See `base/disko-configuration.nix` and `modules/openssh.nix`.

## Module Granularity

Each file in `modules/` covers exactly one system concern:
- `modules/openssh.nix` — SSH daemon, tarpit, fail2ban
- `modules/security.nix` — kernel hardening, AppArmor, auditd, ClamAV, AIDE
- `modules/kernel.nix` — kernel params, sysctl, blacklisted modules
- `modules/secureboot.nix` — lanzaboote, TPM2, first-boot automation
- `modules/pipewire.nix` — audio stack, AirPlay, latency tuning
- `modules/bluetooth.nix` — Bluetooth, OBEX, MPRIS proxy
- `modules/hardware.nix` — firmware, microcode, fwupd, fstrim
- `modules/printing.nix` — CUPS, Avahi mDNS
- `modules/nix.nix` — Nix daemon settings, GC, auto-upgrade
- `modules/zsh.nix` — shell, aliases, Starship prompt, Nerd Fonts

A module is included from a `flake.nix` by adding it to the `modules` list in `nixpkgs.lib.nixosSystem`. See `base/flake.nix` (lines 19–27).

## Error Handling

No runtime error handling constructs exist — this is a declarative configuration language. Idempotency and failure handling for imperative shell scripts inside `systemd.services.*.script` blocks uses guard files and conditional checks:

```bash
if [ -f /var/lib/secureboot-keys-enrolled ]; then
  echo "secureboot [1/2]: already done, skipping"
  exit 0
fi
```

Shell scripts within `script` blocks use explicit `if !` guards before destructive operations (enrolling keys, running cryptenroll). See `modules/secureboot.nix` (lines 67–83, 101–130).

## Language Mixing

Some comments in `.template/` files appear in **Italian** (e.g., `.template/configuration.nix`). Files under `modules/` and `base/` use **English** comments exclusively. New module files should use English comments only.

---

*Convention analysis: 2026-03-06*
