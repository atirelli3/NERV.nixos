# Phase 5: Home Manager Skeleton - Research

**Researched:** 2026-03-07
**Domain:** Home Manager NixOS module — per-user wiring, dynamic user list, impure path imports
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STRUCT-03 | `home/default.nix` skeleton exists with Home Manager NixOS module wired in and `stateVersion` inherited from system | `home-manager.nixosModules.home-manager` is the canonical import; `useGlobalPkgs` and `useUserPackages` are standard; `home.stateVersion` can reference `osConfig.system.stateVersion` since HM passes `osConfig` as a module argument |
| OPT-09 | User can set `nerv.home.enable` and `nerv.home.users` to activate Home Manager for specific users | `home-manager.users` is an attrset; `builtins.listToAttrs` + `map` converts a list of usernames to the attrset; absolute path `/home/<name>/home.nix` requires `--impure` |
</phase_requirements>

---

## Summary

Phase 5 wires Home Manager as a NixOS module through `home/default.nix`, which is already imported by `modules/default.nix` (and therefore by `nixosModules.default`). The module exposes `nerv.home.enable` (enable/disable guard) and `nerv.home.users` (list of usernames). For each listed user, the module sets `home-manager.users.<name>.imports = [ /home/<name>/home.nix ]`. Since `/home/<name>/home.nix` is an absolute path outside the flake boundary, `nixos-rebuild` must be invoked with `--impure`.

The key structural insight: `home/default.nix` itself does NOT import `home-manager.nixosModules.home-manager`. The HM NixOS module must be added to `flake.nix`'s `nixosConfigurations.nixos-base.modules` list (alongside `self.nixosModules.default`). The `home/default.nix` module contributes only the `nerv.home.*` option declarations and their corresponding `home-manager.*` config assignments — it relies on the HM module having been imported at the flake level to provide the `home-manager.*` options.

The `home.stateVersion` value for each user is inherited from `osConfig.system.stateVersion` inside the per-user HM module. Home Manager passes `osConfig` as a special module argument containing the full evaluated NixOS system config. This means the host's `system.stateVersion = "25.11"` flows into each user's HM config automatically — no per-user repetition.

**Primary recommendation:** Wire `home-manager.nixosModules.home-manager` in `flake.nix`, implement `home/default.nix` with a `nerv.home.users` list that generates `home-manager.users` attrset entries via `builtins.listToAttrs`, and document `--impure` as the required build flag.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| home-manager | nixos-unstable branch | NixOS module providing `home-manager.*` options | Already in `flake.nix` inputs; canonical user env manager |
| nixpkgs | nixos-unstable | System packages; shared via `useGlobalPkgs = true` | Already pinned; HM follows it |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lib.mkEnableOption` | nixpkgs lib | Defines `nerv.home.enable` | Standard enable/disable toggle pattern already used in project |
| `lib.mkOption` / `lib.types.listOf lib.types.str` | nixpkgs lib | Defines `nerv.home.users` | Matches `nerv.primaryUser` type already in identity.nix |
| `builtins.listToAttrs` | Nix builtins | Converts `[ "demon" ]` to `{ demon = {...}; }` | Required to generate `home-manager.users` attrset from a list |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `home-manager.users.<name> = { imports = [...]; }` inline | `home-manager.users.<name> = import /home/<name>/home.nix` | Inline form allows `stateVersion` inheritance via `osConfig`; import form is a fixed attrset and cannot access `osConfig` — use inline form |
| absolute path `/home/<name>/home.nix` | path flake input per user | Flake input approach is reproducible but requires the system flake to know about each user's config repo — defeats the "user owns their home.nix" convention |

**Installation (already in flake.nix — no changes to inputs needed):**

```nix
# home-manager is already wired; only flake.nix modules list needs updating:
nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager   # ADD THIS
    self.nixosModules.default
    ./hosts/nixos-base/configuration.nix
  ];
};
```

---

## Architecture Patterns

### Recommended Project Structure After Phase 5

```
/
├── flake.nix                          # UPDATED: home-manager.nixosModules.home-manager added to modules list
└── home/
    └── default.nix                    # REPLACED: stub -> nerv.home.* NixOS module
```

No other files change. The `modules/default.nix` already imports `../home`, so `home/default.nix`'s options and config are automatically included.

### Pattern 1: home-manager.nixosModules.home-manager in flake.nix modules list

**What:** The HM NixOS module must appear in the `modules` list passed to `nixpkgs.lib.nixosSystem`. It provides all `home-manager.*` options. Without it, any reference to `home-manager.useGlobalPkgs` etc. causes "undefined option" evaluation errors.

**When to use:** Always — it is the prerequisite for everything else in Phase 5.

**Example:**
```nix
# Source: home-manager official docs, nix-community.github.io/home-manager/
nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager
    self.nixosModules.default
    ./hosts/nixos-base/configuration.nix
  ];
};
```

### Pattern 2: nerv.home module with listToAttrs user generation

**What:** `home/default.nix` declares `nerv.home.enable` and `nerv.home.users` options. Inside `config = lib.mkIf cfg.enable { ... }`, it generates the `home-manager.users` attrset from the list using `builtins.listToAttrs`.

**When to use:** Whenever a NixOS module needs to derive an attrset from a user-provided list — identical pattern to how `identity.nix` uses `lib.genAttrs` for `nerv.primaryUser`.

**Example:**
```nix
# home/default.nix
# Source: established project pattern (identity.nix uses lib.genAttrs; same approach)

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.home;
in {
  options.nerv.home = {
    enable = lib.mkEnableOption "Home Manager NixOS module wiring";

    users = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Users for whom Home Manager is wired. Each user must maintain ~/home.nix. Requires --impure on nixos-rebuild.";
      example     = [ "demon" ];
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.useGlobalPkgs   = true;
    home-manager.useUserPackages = true;

    home-manager.users = builtins.listToAttrs (map (name: {
      inherit name;
      value = { osConfig, ... }: {
        imports = [ /home/${name}/home.nix ];
        home.stateVersion = osConfig.system.stateVersion;
      };
    }) cfg.users);
  };
}
```

**Key points:**
- `builtins.listToAttrs` converts `[ "demon" ]` to `{ demon = { osConfig, ... }: {...}; }`.
- The per-user value is a **function** (not an attrset), so it receives `osConfig` as a module argument. This is the mechanism for stateVersion inheritance.
- `/home/${name}/home.nix` is an absolute path; string interpolation inside a Nix path literal is valid Nix syntax.
- `--impure` is required at `nixos-rebuild` time because the absolute path is outside the flake boundary.

### Pattern 3: osConfig for stateVersion inheritance

**What:** Home Manager passes `osConfig` as a special module argument to per-user HM module functions. It contains the fully-evaluated NixOS system config, allowing user configs to read `osConfig.system.stateVersion` without hardcoding a version string.

**When to use:** Always in this project — the nerv convention is "no per-user config in the system repo", so the user's `~/home.nix` should not need to know the system stateVersion either.

**Example:**
```nix
# Per-user HM module function inside home-manager.users.<name>
{ osConfig, ... }: {
  imports = [ /home/demon/home.nix ];
  home.stateVersion = osConfig.system.stateVersion;
}
```

This means even the user's `~/home.nix` does NOT need to set `home.stateVersion` — it is provided by the wiring module.

### Pattern 4: backupFileExtension (optional safety)

**What:** `home-manager.backupFileExtension` sets a backup suffix for any files HM would overwrite during activation. When not set, HM will fail if a target file already exists unmanaged.

**When to use:** Optional — set to `"backup"` if the deployment environment might have pre-existing dotfiles that HM would conflict with. The nerv convention (user owns `~/home.nix`, system only provides wiring) makes conflicts unlikely, but it is a safe default.

**Example:**
```nix
home-manager.backupFileExtension = "backup";
```

### Anti-Patterns to Avoid

- **Not adding `home-manager.nixosModules.home-manager` to `flake.nix`:** The `home/default.nix` module assigns to `home-manager.*` options. If HM module is not in the modules list, these options do not exist and evaluation fails with "undefined option". This is the most likely mistake.
- **Setting `home-manager.users.<name> = import /home/<name>/home.nix`:** Using `import` directly passes an attrset, not a function — `osConfig` will not be available, and `home.stateVersion` cannot be inherited. Always use a function: `{ osConfig, ... }: { imports = [ /home/${name}/home.nix ]; }`.
- **Using `lib.mkMerge` to build `home-manager.users`:** The `home-manager.users` option is of type `attrsOf (submoduleWith ...)`. Setting it with `lib.mkMerge` applied to a listToAttrs result is not needed — a plain attrset assignment inside `lib.mkIf` is correct. The HM module system handles merging internally.
- **Forgetting `--impure` in the success-criteria build command:** The phase success criterion explicitly calls for `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure`. A plain `nixos-rebuild build` without `--impure` will fail at evaluation with "access to absolute path '/home/...' is forbidden in pure eval mode" even if the file exists.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-user HM config wiring | Custom activation scripts or systemd services | `home-manager.users.<name>` option | HM NixOS module handles activation ordering, profile generation, and service units |
| stateVersion propagation | Per-user string literal or a separate option | `osConfig.system.stateVersion` via HM module function argument | HM already exposes `osConfig`; no indirection needed |
| User attrset from list | Custom `lib.foldl` or `lib.mkMerge` constructs | `builtins.listToAttrs` + `map` | Idiomatic Nix; same shape as `lib.genAttrs` already used in identity.nix |

**Key insight:** HM NixOS module does the heavy lifting — profile directories, systemd activation units, collision detection. Do not replicate any of this.

---

## Common Pitfalls

### Pitfall 1: HM NixOS module not in flake.nix modules list

**What goes wrong:** `nixos-rebuild` fails with `error: The option 'home-manager.useGlobalPkgs' does not exist.`

**Why it happens:** `home/default.nix` assigns to `home-manager.*` config, but the option definitions live in `home-manager.nixosModules.home-manager`. If that module is not in the system's modules list, the options are undefined.

**How to avoid:** Add `home-manager.nixosModules.home-manager` to `nixosConfigurations.nixos-base.modules` in `flake.nix` BEFORE implementing `home/default.nix`.

**Warning signs:** "does not exist" errors mentioning `home-manager.*` options.

### Pitfall 2: Pure evaluation rejects absolute home path

**What goes wrong:** `nixos-rebuild switch --flake /etc/nerv#nixos-base` (without `--impure`) fails with: `error: access to absolute path '/home/demon/home.nix' is forbidden in pure eval mode`.

**Why it happens:** Nix flakes enforce pure evaluation by default. Any reference to an absolute filesystem path outside the flake directory is blocked.

**How to avoid:** Always use `--impure` when building with the HM wiring. Document this in the host's configuration.nix comment and in the nerv README.

**Warning signs:** "forbidden in pure eval mode" errors referencing `/home/`.

### Pitfall 3: home.stateVersion not set causes HM warning/error

**What goes wrong:** `nixos-rebuild switch` completes but systemctl shows `home-manager-<name>.service` failed with: `error: The option 'home.stateVersion' is used but not defined.`

**Why it happens:** The user's `~/home.nix` does not set `home.stateVersion`, and the wiring module forgot to set it in the per-user module function.

**How to avoid:** Always set `home.stateVersion = osConfig.system.stateVersion;` in the per-user function value inside `home-manager.users`, NOT as an expectation from the user's `~/home.nix`.

**Warning signs:** Activation service failure mentioning `home.stateVersion`.

### Pitfall 4: Using import form instead of function form for per-user value

**What goes wrong:** `home-manager.users.demon = import /home/demon/home.nix;` is an attrset import — `osConfig` is not passed, and `home.stateVersion = osConfig.system.stateVersion` inside that import fails with "undefined variable 'osConfig'".

**Why it happens:** `home-manager.users.<name>` accepts HM modules — either attrsets or functions. Only the function form receives special module arguments like `osConfig`. `import /home/...` evaluates to an attrset, losing the function argument injection.

**How to avoid:** Always use the function form: `home-manager.users.<name> = { osConfig, ... }: { imports = [...]; home.stateVersion = osConfig.system.stateVersion; };`. The user's `~/home.nix` is imported inside the function, not as the function itself.

**Warning signs:** "undefined variable 'osConfig'" in the user's home.nix, or stateVersion errors.

### Pitfall 5: ~/home.nix does not exist at evaluation time

**What goes wrong:** `nixos-rebuild switch --impure` fails with: `error: getting status of '/home/demon/home.nix': No such file or directory`.

**Why it happens:** The absolute path `/home/demon/home.nix` is accessed at evaluation time (not activation time). If the user has not yet created their `~/home.nix`, evaluation fails even though `--impure` allows the access attempt.

**How to avoid:** The user must create a minimal `~/home.nix` before `nixos-rebuild` is run with `nerv.home.users = [ "demon" ]`. Document the expected minimal content in a comment in `home/default.nix`.

**Warning signs:** "No such file or directory" for `/home/<name>/home.nix`.

**Recommended minimal `~/home.nix` for the user:**
```nix
# ~/home.nix — user-owned Home Manager configuration
# home.stateVersion is set by the system wiring (nerv); do not set it here.
{ pkgs, ... }: {
  home.username = "demon";
  home.homeDirectory = "/home/demon";
}
```

### Pitfall 6: nerv.home.enable not set in configuration.nix

**What goes wrong:** `home/default.nix` is imported, but since `enable = false` by default, no HM config is applied. Users wonder why HM is not active.

**Why it happens:** `lib.mkEnableOption` defaults to `false`. The host must explicitly set `nerv.home.enable = true` and `nerv.home.users = [ "demon" ]`.

**How to avoid:** Add these to `hosts/nixos-base/configuration.nix` during phase implementation and verify the full build succeeds.

---

## Code Examples

Verified patterns from project codebase and official sources:

### home/default.nix — Complete Phase 5 Implementation

```nix
# home/default.nix
#
# Purpose  : Wires Home Manager as a NixOS module for each user in nerv.home.users.
# Convention: Each listed user owns ~/home.nix. nerv imports it automatically.
#             The user's ~/home.nix does NOT need to set home.stateVersion.
# Options  : nerv.home.enable, nerv.home.users
# Defaults : enable = false; users = []
# Override : lib.mkForce on any home-manager.* setting.
# Note     : nixos-rebuild requires --impure because /home/<name>/home.nix is
#            outside the flake boundary.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.home;
in {
  options.nerv.home = {
    enable = lib.mkEnableOption "Home Manager NixOS module wiring";

    users = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = ''
        Users for whom Home Manager is activated. Each user must maintain
        ~/home.nix containing their personal configuration (packages, programs,
        dotfiles). The system repo does not manage the contents of ~/home.nix.
        Adding a user here automatically imports /home/<name>/home.nix.
        Requires nixos-rebuild --impure.
      '';
      example     = [ "demon" "alice" ];
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.useGlobalPkgs   = true;
    home-manager.useUserPackages = true;

    # Generate home-manager.users attrset from the users list.
    # Each value is a function so it receives osConfig as a module argument,
    # enabling stateVersion inheritance without hardcoding.
    home-manager.users = builtins.listToAttrs (map (name: {
      inherit name;
      value = { osConfig, ... }: {
        imports = [ /home/${name}/home.nix ];
        # Inherit stateVersion from system — user's ~/home.nix need not set this.
        home.stateVersion = osConfig.system.stateVersion;
      };
    }) cfg.users);
  };
}
```

### flake.nix — Updated nixosConfigurations.nixos-base modules list

```nix
# Source: Phase 1 established flake shape; HM NixOS module added here

nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    lanzaboote.nixosModules.lanzaboote
    home-manager.nixosModules.home-manager   # wires home-manager.* options
    self.nixosModules.default
    ./hosts/nixos-base/configuration.nix
  ];
};
```

### hosts/nixos-base/configuration.nix — Enabling the wiring

```nix
# Add to existing configuration.nix:
nerv.home.enable = true;
nerv.home.users  = [ "demon0" ];
```

### Verification Commands

```bash
# 1. Stage changes
git add home/default.nix flake.nix hosts/nixos-base/configuration.nix

# 2. Verify flake still evaluates (pure — will fail only if home-manager.* option
#    wiring is broken in a way that doesn't touch absolute paths)
nix flake show

# 3. Full build with --impure (required for /home/<name>/home.nix path resolution)
nixos-rebuild switch --flake /etc/nerv#nixos-base --impure

# 4. Verify HM activation succeeded
systemctl status home-manager-demon0.service
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `home-manager switch` as a separate command per user | `nixos-rebuild switch` activates HM as a NixOS module | HM NixOS module introduced ~2020 | Single command for system + user config |
| `home.stateVersion` hardcoded per user | `osConfig.system.stateVersion` via HM module argument | HM added `osConfig` arg ~2022 | Version stays in sync automatically |
| `home-manager.nixosModule` (singular) | `home-manager.nixosModules.home-manager` (plural, named) | Flakes convention established ~2022 | Matches standard flake output schema |

**Deprecated/outdated:**
- `<home-manager/nixos>` channel import: Old non-flake pattern. Not used in this project — flake input is already wired.
- `home-manager.nixosModule` (singular): Older alias, still works but non-standard. Use `home-manager.nixosModules.home-manager`.

---

## Open Questions

1. **backupFileExtension**
   - What we know: HM will refuse to activate if a target file already exists and is not managed by HM.
   - What's unclear: Whether the deploy environment (existing user home) has files that would conflict.
   - Recommendation: Include `home-manager.backupFileExtension = "backup";` in the wiring module as a safety default. It is harmless when there are no conflicts and prevents hard failures when there are.

2. **nerv.home.users vs nerv.primaryUser overlap**
   - What we know: `nerv.primaryUser` controls OS-level user group membership. `nerv.home.users` controls HM activation. They are independent — a user can be in one without the other.
   - What's unclear: Whether the planner should add an assertion that all `nerv.home.users` entries also appear in `users.users` (i.e., are declared OS users). The phase requirements do not mandate this assertion.
   - Recommendation: No assertion for now — keep the two options independent. A user could theoretically be an OS user without HM or have HM without `nerv.primaryUser` wiring.

3. **~/home.nix not existing at evaluation time**
   - What we know: The absolute path is accessed at Nix evaluation time, not activation time.
   - What's unclear: Should the module guard against missing `~/home.nix` gracefully, or let it fail loudly?
   - Recommendation: Let it fail loudly (no guard). A missing `~/home.nix` is a user configuration error and should produce a clear error message. Document the required minimal content.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (NixOS — validation uses `nix` CLI and `systemctl`) |
| Config file | none |
| Quick run command | `nix flake show` |
| Full suite command | `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRUCT-03 | `home/default.nix` sets `useGlobalPkgs = true`, `useUserPackages = true`, inherits `stateVersion` | smoke | `grep -E 'useGlobalPkgs\|useUserPackages\|stateVersion' home/default.nix` | Wave 0 creates it |
| OPT-09 | `nerv.home.users = [ "demon0" ]` imports `/home/demon0/home.nix` | integration | `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure && systemctl status home-manager-demon0.service` | Wave 0 creates home/default.nix |
| (SC-3) | Adding a second user works without other changes | integration | Add second user to `nerv.home.users`, rebuild, check second service | manual test |
| (SC-4) | nixos-rebuild switch --impure succeeds | integration | `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure` | requires ~/home.nix to exist |

### Sampling Rate

- **Per task commit:** `nix flake show` (fast; confirms option wiring compiles)
- **Per wave merge:** `nixos-rebuild switch --flake /etc/nerv#nixos-base --impure`
- **Phase gate:** Full suite green + `systemctl status home-manager-demon0.service` active before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `home/default.nix` — replace stub with full nerv.home.* module
- [ ] `flake.nix` — add `home-manager.nixosModules.home-manager` to nixosConfigurations modules list
- [ ] `hosts/nixos-base/configuration.nix` — add `nerv.home.enable = true` and `nerv.home.users = [ "demon0" ]`
- [ ] User prerequisite: `~/home.nix` must exist for the build to succeed (document minimal content)

No test framework installation needed — validation uses `nix` CLI and `systemctl` (native to NixOS).

---

## Sources

### Primary (HIGH confidence)

- `/home/demon/Developments/test-nerv.nixos/home/default.nix` — current stub confirming Phase 5 is the target
- `/home/demon/Developments/test-nerv.nixos/flake.nix` — confirmed `home-manager` is in inputs, NOT yet in modules list
- `/home/demon/Developments/test-nerv.nixos/modules/default.nix` — confirmed `../home` is already imported; no flake.nix change needed for that
- `/home/demon/Developments/test-nerv.nixos/modules/system/identity.nix` — `lib.genAttrs` / `listOf str` pattern for user list options; model for `nerv.home.users`
- `.planning/STATE.md` decisions — `home-manager.nixosModules.home-manager` is canonical attribute name (Phase 1 decision); `nerv.home.users` convention locked
- `.planning/ROADMAP.md` Phase 5 success criteria — authoritative specification

### Secondary (MEDIUM confidence)

- [nix-community.github.io/home-manager/](https://nix-community.github.io/home-manager/) — confirmed `useGlobalPkgs`, `useUserPackages`, NixOS module installation pattern
- [wiki.nixos.org/wiki/Home_Manager](https://wiki.nixos.org/wiki/Home_Manager) — `home-manager.nixosModules.default` alias confirmed; `home-manager.users.<name> = ./home.nix` import pattern
- [drakerossman.com/blog/how-to-add-home-manager-to-nixos](https://drakerossman.com/blog/how-to-add-home-manager-to-nixos) — `--impure` requirement for absolute paths outside flake boundary
- WebSearch results confirming `osConfig` is passed as HM module argument for stateVersion inheritance

### Tertiary (LOW confidence)

- WebSearch results on `builtins.listToAttrs` + map for dynamic HM users — consistent with Nix language semantics but not verified against HM's type definition for `home-manager.users`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — home-manager input already in flake.nix; module attribute name locked in STATE.md
- Architecture: HIGH — wiring pattern confirmed by official docs and existing project options pattern
- `--impure` requirement: HIGH — confirmed by multiple sources; fundamental Nix flake purity constraint
- `osConfig.system.stateVersion` inheritance: MEDIUM — `osConfig` arg confirmed by HM docs; exact field name `system.stateVersion` verified against NixOS option but not tested in this exact wiring
- `builtins.listToAttrs` for `home-manager.users`: MEDIUM — Nix language semantics confirmed; HM type acceptance of function-valued attrset entries confirmed by docs but not verified against current HM source

**Research date:** 2026-03-07
**Valid until:** 2026-09-07 (home-manager NixOS module API is stable; `--impure` is a fundamental Nix flake constraint unlikely to change)
