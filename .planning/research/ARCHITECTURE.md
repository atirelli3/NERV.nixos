# Architecture Research: nerv.nixos

**Project:** nerv.nixos — NixOS module library refactor
**Focus:** Component boundaries, directory structure, build order
**Confidence:** HIGH (based on codebase analysis + stable NixOS module system behavior)

---

## Module Boundary Rules

### modules/system/

Files whose misconfiguration can cause boot failure or that operate in kernel space:

| File | Notes |
|------|-------|
| `hardware.nix` | CPU microcode, GPU drivers — machine-specific |
| `kernel.nix` | Kernel package, kernel params, modules |
| `secureboot.nix` | Lanzaboote — must come after bootloader |
| `security.nix` | AppArmor, audit, hardening — kernel-coupled |
| `nix.nix` | Nix daemon config, GC, sandbox |
| `boot.nix` | **Extract from base/configuration.nix** — loader, initrd, LUKS |
| `impermanence.nix` | tmpfs root — affects every mount, belongs in system/ |

**Rule:** If misconfiguration bricks the system or requires a live USB to fix → `system/`.

### modules/services/

Services that can be toggled without risk to the boot chain:

| File | Notes |
|------|-------|
| `openssh.nix` | SSH daemon + fail2ban + endlessh |
| `pipewire.nix` | Audio — userspace |
| `bluetooth.nix` | Bluetooth + OBEX |
| `printing.nix` | CUPS — depends on Avahi (from pipewire.nix) |
| `zsh.nix` | Shell — userspace |

---

## Aggregator Pattern

Each subdirectory gets a `default.nix` with only `imports`:

```nix
# modules/system/default.nix
{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./kernel.nix
    ./nix.nix
    ./secureboot.nix
    ./security.nix
    ./impermanence.nix
  ];
}
```

Importing a directory automatically imports its `default.nix` — core Nix behavior. Host flakes import the directory, not individual files.

---

## flake.nix Export Pattern

The root flake exposes named module sets:

```nix
nixosModules = {
  system   = import ./modules/system;   # imports default.nix
  services = import ./modules/services;
  home     = import ./home;
  default  = { imports = [ self.nixosModules.system self.nixosModules.services self.nixosModules.home ]; };
};
```

Host flake usage:
```nix
imports = [ nerv.nixosModules.default ];
nerv.hardware.cpu = "amd";
nerv.openssh.allowUsers = [ "alice" ];
```

---

## Home Manager Integration

Use `home-manager.nixosModules.home-manager` (NixOS module mode) — single `nixos-rebuild switch` workflow, no separate `home-manager switch`.

```nix
# In flake.nix inputs:
home-manager.url = "github:nix-community/home-manager";
home-manager.inputs.nixpkgs.follows = "nixpkgs";  # REQUIRED

# In nixosConfigurations:
modules = [
  nerv.nixosModules.default
  home-manager.nixosModules.home-manager
  {
    home-manager.useGlobalPkgs = true;    # use system nixpkgs
    home-manager.useUserPackages = true;  # install to /etc/profiles
    home-manager.users.<name> = import ./home/users/<name>.nix;
  }
];
```

`home/default.nix` skeleton sets global HM defaults only. Per-user config stays in the host flake.

---

## Build Order

1. Create empty directory skeleton + stub `default.nix` aggregators
2. Move `modules/services/` files (lower risk, no boot dependency)
3. Move `modules/system/` files — leave `kernel.nix` and `secureboot.nix` for last
4. Extract `boot.nix` from `base/configuration.nix`
5. Update flake.nix import paths to use aggregators + add new inputs (home-manager, impermanence)
6. Wire in `home/default.nix` skeleton
7. Add `options.nerv.*` blocks and documentation headers to all modules

---

## Anti-Patterns

- Importing individual module files from host flakes (defeats aggregators)
- Mixing system/service concerns in one file
- Hardcoding machine-specific values (hostname, CPU type, username) in shared modules
- Running standalone `home-manager switch` instead of NixOS module mode
- Skipping the aggregator `default.nix` layer in root flake exports
