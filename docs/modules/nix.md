# Module: Nix

**File:** `modules/system/nix.nix`

Nix daemon configuration, garbage collection, store optimisation, and automatic upgrades. Fully opaque — always active.

---

## What it configures

### Nix daemon settings

| Setting | Value | Effect |
|---------|-------|--------|
| `nix.settings.experimental-features` | `["nix-command" "flakes"]` | Enables flakes and nix CLI |
| `nix.channel.enable` | `false` | Disables legacy Nix channels |
| `nix.settings.allowed-users` | `["@wheel"]` | Restricts Nix daemon access to wheel group |
| `nix.settings.trusted-users` | `["root" "@wheel"]` | Allows wheel users to set trusted Nix settings |
| `nix.settings.auto-optimise-store` | `true` | Deduplicates store paths with hardlinks on each build |
| `nixpkgs.config.allowUnfree` | `true` | Allows proprietary packages (NVIDIA drivers, etc.) |

### Garbage collection

Weekly GC run — deletes generations older than 20 days:

```nix
nix.gc = {
  automatic = true;
  dates     = "weekly";
  options   = "--delete-older-than 20d";
};
```

### Store optimisation

Weekly full optimisation pass (hardlinks across all store paths):

```nix
nix.optimise = {
  automatic = true;
  dates     = [ "weekly" ];
};
```

### Auto-upgrade

Daily pull from the local flake — no automatic reboot:

```nix
system.autoUpgrade = {
  enable      = true;
  flake       = "/etc/nixos#host";
  allowReboot = false;
  dates       = "daily";
};
```

> **Known limitation:** `system.autoUpgrade.flake` is hardcoded to `#host`. If you are using the `#server` profile, override this in `hosts/configuration.nix`:
> ```nix
> system.autoUpgrade.flake = lib.mkForce "/etc/nixos#server";
> ```

---

## Manual operations

```bash
# Force garbage collection now
nix-collect-garbage --delete-older-than 20d

# Optimise store now
nix store optimise

# Update all flake inputs
sudo nix flake update /etc/nixos

# List current system generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to previous generation
sudo nix-env --rollback --profile /nix/var/nix/profiles/system
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

---

## Override examples

```nix
# hosts/configuration.nix
{ lib, ... }: {
  # Disable auto-upgrade (e.g. for production servers)
  system.autoUpgrade.enable = lib.mkForce false;

  # Change GC retention period
  nix.gc.options = lib.mkForce "--delete-older-than 7d";

  # Allow specific additional users to use Nix
  nix.settings.allowed-users = lib.mkForce ["@wheel" "ci-runner"];
}
```
