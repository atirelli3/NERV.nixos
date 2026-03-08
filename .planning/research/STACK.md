# Stack Research: nerv.nixos

**Project:** nerv.nixos — NixOS module library refactor
**Mode:** Ecosystem — Stack dimension
**Confidence:** MEDIUM (based on training cutoff Aug 2025 + existing codebase evidence)

---

## Key Findings

### NixOS Module Options API

`lib.mkOption`, `lib.types`, `lib.mkIf`, `lib.mkDefault`, `lib.mkForce` are stable and unchanged through NixOS 25.11. The `options`/`config` split with `cfg = config.nerv.<name>` is the canonical refactor target.

**Pattern:**
```nix
options.nerv.openssh = {
  enable = lib.mkEnableOption "SSH daemon" // { default = true; };
  allowUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Users allowed to SSH in. Empty = all users.";
  };
  passwordAuth = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Allow password authentication. Disabled by default.";
  };
};

config = lib.mkIf cfg.enable {
  services.openssh.settings.PasswordAuthentication = cfg.passwordAuth;
  services.openssh.settings.AllowUsers = lib.mkIf (cfg.allowUsers != []) cfg.allowUsers;
};
```

### Home Manager Flake Integration

Input: `github:nix-community/home-manager` with `inputs.nixpkgs.follows = "nixpkgs"` (hard requirement to avoid double nixpkgs evaluation).

Module attribute: `home-manager.nixosModules.home-manager`

**Recommended settings:**
```nix
home-manager.useGlobalPkgs = true;    # use system nixpkgs
home-manager.useUserPackages = true;  # install to /etc/profiles
```

**Verify:** `nix flake show github:nix-community/home-manager` — confirm exact `nixosModules` attribute name.

### Impermanence

Input: `github:nix-community/impermanence` (no version pin needed — tracks main).
Module: `impermanence.nixosModules.impermanence`

**Note:** The "impermanence for ~/Downloads, /tmp, ~/Desktop" goal is automatically satisfied by tmpfs root — those paths are ephemeral unless explicitly listed in `environment.persistence`. The impermanence module is primarily needed to *persist* specific dirs (e.g. `/etc/nixos`, `/var/lib`), not to wipe them.

**User-level persistence:**
```nix
environment.persistence."/persist".users.<name> = {
  directories = [ "Documents" ".config/nvim" ];
  files = [ ".ssh/authorized_keys" ];
};
```

### Namespace Convention

All module options use `nerv.<moduleName>` namespace to avoid collision with upstream NixOS options.

### Security-mandatory vs User-tunable Settings

Modules with security-mandatory settings (`kernel.nix`, `secureboot.nix`) must use `lib.mkForce` on those settings and `lib.mkDefault` for user-tunable ones. The refactor must not flatten these categories.

---

## Confidence Table

| Area | Level | Reason |
|------|-------|--------|
| `lib.mkOption` / types API | HIGH | Stable NixOS core API |
| HM flake input + nixosModules attribute | MEDIUM | Well-documented; verify with nix flake show |
| `useGlobalPkgs` / `useUserPackages` | MEDIUM | Stable through 24.x |
| Impermanence input URL + API | HIGH | Confirmed by existing .template/ files in repo |
| Lanzaboote `v0.4.1` pin currency | MEDIUM | Tag present in repo; online verification needed |

---

## Roadmap Implications

1. **flake.nix update** — Add `home-manager` and `impermanence` as inputs. One-time change, must happen in Phase 1.
2. **Home Manager skeleton** — Single `home/default.nix` exposing `nerv.home.enable` and `nerv.home.userName`; users extend in their host flake.
3. **Module options refactor** — Each module in `modules/` gets an `options.nerv.<name>` block; existing hardcoded values become `lib.mkDefault` where user-tunable, `lib.mkForce` where security-mandatory.

---

## Open Questions

1. Whether lanzaboote `v0.4.1` is still current — check upstream tags.
2. Exact `nixosModules` attribute in HM flake — run `nix flake show`.
3. Whether `home-manager.backupFileExtension` is the correct option name in 25.11-era HM.
