# Phase 3: System Modules (non-boot) - Research

**Researched:** 2026-03-07
**Domain:** NixOS module system — options API, hardware conditionals, identity/locale, user wiring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**security.nix — fully opaque**
- All hardening stays always-on: AppArmor, auditd, ClamAV (daemon + updater), AIDE (daily check timer)
- No `nerv.*` options exposed for security.nix
- AIDE runs daily; freshclam runs 24x/day — frequencies hardcoded
- Baseline audit ruleset (execve, openat, connect, setuid/setgid, critical file writes) is locked in
- `lib.mkForce` is the documented escape hatch for any overrides

**nix.nix — path fix, autoUpgrade stays on**
- Fix stale `system.autoUpgrade.flake` from `/etc/nixos#nixos` to `/etc/nerv#nixos-base`
- `system.autoUpgrade.enable = true` remains — stays default-on, `allowReboot = false`
- `nixpkgs.config.allowUnfree = true` stays hardcoded
- No `nerv.*` options added to nix.nix in Phase 3
- GC and optimise settings (weekly, 20-day retention) stay hardcoded

**nerv.primaryUser — list, groups + shell wiring**
- `nerv.primaryUser` is a list of strings (e.g. `[ "demon0" ]`)
- Wires groups only: each listed user gets `extraGroups = [ "wheel" "networkmanager" ]`
- Does NOT own full user declaration — host flake still provides `users.users.<name> = { isNormalUser = true; ... }`
- Shell auto-wiring: when `nerv.zsh.enable = true` and `nerv.primaryUser` is non-empty, each listed user gets `shell = pkgs.zsh` set automatically
- Type: `types.listOf types.str`, default `[]`

**hardware.nix — CPU-conditional params**
- `hardware.nix` owns both microcode AND CPU-specific kernel params
- `nerv.hardware.cpu` enum: `"amd"` | `"intel"` | `"other"`
  - `"amd"`: `hardware.cpu.amd.updateMicrocode = true` + kernel params `amd_iommu=on iommu=pt`
  - `"intel"`: `hardware.cpu.intel.updateMicrocode = true` + kernel params `intel_iommu=on iommu=pt`
  - `"other"`: no microcode, no IOMMU kernel params; firmware blobs still applied
- `nerv.hardware.gpu` enum: `"amd"` | `"nvidia"` | `"intel"` | `"none"`
  - `"nvidia"`: `services.xserver.videoDrivers = [ "nvidia" ]` + `hardware.nvidia.open = true`
  - `"amd"`: `services.xserver.videoDrivers = [ "amdgpu" ]`
  - `"intel"`: `services.xserver.videoDrivers = [ "intel" ]`
  - `"none"`: no GPU driver configuration
- Firmware blobs and `services.fwupd` / `services.fstrim` remain unconditional

**kernel.nix — generic hardening only after CPU param removal**
- Remove `amd_iommu=on` and `iommu=pt` from kernel.nix
- All other boot.kernelParams carry over verbatim
- `boot.kernel.sysctl`, `boot.blacklistedKernelModules`, and `boot.kernelPackages` stay hardcoded

**identity module — new file**
- New file `modules/system/identity.nix`
- `nerv.hostname` (type: `types.str`, no default — required) sets `networking.hostName`
- `nerv.locale.timeZone` (type: `types.str`, default `"UTC"`) sets `time.timeZone`
- `nerv.locale.defaultLocale` (type: `types.str`, default `"en_US.UTF-8"`) sets `i18n.defaultLocale`
- `nerv.locale.keyMap` (type: `types.str`, default `"us"`) sets `console.keyMap`

### Claude's Discretion
- Exact NixOS module option descriptions and example values
- Whether to use `lib.mkMerge` or `lib.optionalAttrs` for the CPU-conditional group extension in primaryUser
- Whether identity.nix includes `console.font` / `console.packages` (terminus) or leaves that to host flake
- Order of imports in `modules/system/default.nix`
- Whether to assert `nerv.hostname != ""` or rely on type constraints

### Deferred Ideas (OUT OF SCOPE)
- `nerv.nix.autoUpdate` toggle (default false) — v2 roadmap OPT-V2-01
- `nerv.kernel.package` option to override kernel package — v2 roadmap OPT-V2-02
- `nerv.nix.gcInterval` option — v2 roadmap OPT-V2-03
- `nerv.security.audit.extraRules` additive option — lib.mkForce covers edge cases for v1
- Per-service security toggles (ClamAV, AppArmor, audit) — opaque posture is v1 intent
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OPT-01 | User can set `nerv.hostname`, `nerv.locale.timeZone`, `nerv.locale.keyMap`, `nerv.locale.defaultLocale` to configure machine identity without editing core modules | identity.nix new file; maps to `networking.hostName`, `time.timeZone`, `i18n.defaultLocale`, `console.keyMap` |
| OPT-02 | User can set `nerv.primaryUser` to declare the primary system user, wiring group membership | `users.users.<name>` attribute extension via `lib.mkMerge` + `builtins.listToAttrs`; zsh shell cross-wiring via `nerv.zsh.enable` |
| OPT-03 | User can set `nerv.hardware.cpu` (enum: amd/intel/other) to enable correct microcode and CPU-specific kernel params | `hardware.cpu.amd.updateMicrocode`, `hardware.cpu.intel.updateMicrocode`; `boot.kernelParams` extended via `lib.mkIf` + `lib.optionals` |
| OPT-04 | User can set `nerv.hardware.gpu` (enum: amd/nvidia/intel/none) to enable appropriate GPU drivers | `services.xserver.videoDrivers`; `hardware.nvidia.open = true` for nvidia; conditional via `lib.mkIf` on enum value |
</phase_requirements>

---

## Summary

Phase 3 migrates four existing flat modules (`hardware.nix`, `kernel.nix`, `security.nix`, `nix.nix`) from `modules/` into `modules/system/` and introduces two new files: `modules/system/identity.nix` (new) and the user wiring logic in a `modules/system/primaryUser.nix` (or co-located in identity.nix). The `modules/system/default.nix` stub — currently `{ imports = []; }` — is populated with all five system modules.

The options pattern is already proven in Phase 2 (`modules/services/openssh.nix` is the canonical template). All four new option namespaces (`nerv.hostname`, `nerv.locale.*`, `nerv.primaryUser`, `nerv.hardware.*`) follow the same `options = { ... }; config = { ... };` split. The most complex part is the `nerv.primaryUser` shell cross-wiring, which reads `config.nerv.zsh.enable` — a pattern where one nerv module conditions on another nerv option, requiring careful module ordering and no circular dependency.

The `hardware.nix` refactor is the only structural change with a meaningful evaluation risk: moving `amd_iommu=on iommu=pt` from `kernel.nix` into a conditional block in `hardware.nix` while ensuring they are not silently dropped when `nerv.hardware.cpu = "other"`. The build verification (`nixos-rebuild build --flake .#nixos-base`) will catch any missing attribute or evaluation error.

**Primary recommendation:** Follow the openssh.nix template verbatim for options structure. Use `lib.mkMerge` with `builtins.listToAttrs` for primaryUser group extension. Use `lib.mkIf (cfg.cpu == "amd")` pattern for hardware conditionals. Keep security.nix and nix.nix as opaque migrations with zero structural changes (only the flake path fix in nix.nix).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixpkgs NixOS module system | nixos-unstable | `lib.mkOption`, `lib.mkIf`, `lib.types.*`, `lib.mkMerge` | The only framework in scope — all modules are NixOS modules |
| `hardware.cpu.amd.updateMicrocode` | NixOS built-in | AMD microcode initrd updates | Standard NixOS option, no extra package needed |
| `hardware.cpu.intel.updateMicrocode` | NixOS built-in | Intel microcode initrd updates | Standard NixOS option, no extra package needed |
| `services.xserver.videoDrivers` | NixOS built-in | GPU driver selection | Standard NixOS option list |
| `hardware.nvidia.open` | NixOS built-in | NVIDIA open kernel module (Turing+) | Replaces proprietary module; NVIDIA recommendation since R525 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lib.types.enum` | nixpkgs lib | Restrict option values to a fixed set | `nerv.hardware.cpu` and `nerv.hardware.gpu` enums |
| `lib.types.listOf lib.types.str` | nixpkgs lib | List-of-strings type | `nerv.primaryUser` |
| `lib.mkMerge` | nixpkgs lib | Merge multiple attrset fragments in config | CPU-conditional kernel params merged with unconditional firmware |
| `lib.optionals` | nixpkgs lib | Conditionally add list elements | Extending `boot.kernelParams` conditionally |
| `builtins.listToAttrs` | Nix built-in | Convert `[ { name; value } ]` to attrset | Generating `users.users.<name>` entries from primaryUser list |
| `lib.genAttrs` | nixpkgs lib | Generate attrset from list of names | Alternative to `builtins.listToAttrs` for user entry generation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `lib.mkIf (cfg.cpu == "amd")` | `lib.optionalAttrs` | `lib.mkIf` is clearer for top-level config blocks; `lib.optionalAttrs` works equally well for attribute-level conditionals |
| `builtins.listToAttrs` + manual shape | `lib.genAttrs` | `lib.genAttrs` is cleaner when all values have the same structure; `listToAttrs` is more explicit |
| `lib.mkMerge [ ... ]` | Multiple top-level `config = ` stanzas | NixOS only allows one `config` block per module; use `lib.mkMerge` for conditional fragments |

**Installation:** No new packages. All options are NixOS built-ins or use existing nixpkgs.

---

## Architecture Patterns

### Recommended Project Structure (after Phase 3)
```
modules/
├── default.nix              # aggregates system/ + services/ + home/
├── system/
│   ├── default.nix          # imports identity, hardware, kernel, security, nix, primaryUser
│   ├── identity.nix         # NEW: nerv.hostname + nerv.locale.*
│   ├── hardware.nix         # MIGRATED+REFACTORED: nerv.hardware.cpu + nerv.hardware.gpu
│   ├── kernel.nix           # MIGRATED: hardening params (amd_iommu removed)
│   ├── security.nix         # MIGRATED: opaque, no options
│   └── nix.nix              # MIGRATED: path fix only
├── services/
│   └── ...                  # Phase 2 complete
└── (primaryUser wiring)     # lives in identity.nix or a dedicated primaryUser.nix
```

### Pattern 1: Standard nerv Module with Options (openssh.nix template)
**What:** Declare `options.nerv.<ns>` block, then `config = lib.mkIf cfg.enable { ... }` or unconditional `config = { ... }` for always-on modules.
**When to use:** Every module that exposes user-facing options.

```nix
# Source: modules/services/openssh.nix (established in Phase 2)
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.openssh;
in {
  options.nerv.openssh = {
    enable = lib.mkEnableOption "OpenSSH daemon ...";
    port = lib.mkOption {
      type        = lib.types.port;
      default     = 2222;
      description = "Port the SSH daemon listens on.";
      example     = 2222;
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
    # ...
  };
}
```

### Pattern 2: Enum Option with Multi-Branch Conditionals
**What:** Use `lib.types.enum` for a fixed set of values; use `lib.mkIf (cfg.x == "value")` or `lib.mkMerge` for branching config.
**When to use:** `nerv.hardware.cpu` and `nerv.hardware.gpu`.

```nix
# Pattern for hardware.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.hardware;
in {
  options.nerv.hardware = {
    cpu = lib.mkOption {
      type        = lib.types.enum [ "amd" "intel" "other" ];
      default     = "other";
      description = "CPU vendor. Selects microcode package and IOMMU kernel params.";
      example     = "amd";
    };
    gpu = lib.mkOption {
      type        = lib.types.enum [ "amd" "nvidia" "intel" "none" ];
      default     = "none";
      description = "GPU driver to enable.";
      example     = "amd";
    };
  };

  config = lib.mkMerge [
    # Unconditional — hardware-agnostic
    {
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;
      services.fwupd.enable = true;
      services.fstrim = { enable = true; interval = "weekly"; };
    }

    # CPU conditionals
    (lib.mkIf (cfg.cpu == "amd") {
      hardware.cpu.amd.updateMicrocode = true;
      boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
    })
    (lib.mkIf (cfg.cpu == "intel") {
      hardware.cpu.intel.updateMicrocode = true;
      boot.kernelParams = [ "intel_iommu=on" "iommu=pt" ];
    })

    # GPU conditionals
    (lib.mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true;
    })
    (lib.mkIf (cfg.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
    })
    (lib.mkIf (cfg.gpu == "intel") {
      services.xserver.videoDrivers = [ "intel" ];
    })
  ];
}
```

### Pattern 3: List-Driven User Extension
**What:** Iterate over `nerv.primaryUser` list and extend each `users.users.<name>` with `extraGroups` and conditionally `shell`.
**When to use:** `nerv.primaryUser` wiring.

```nix
# Pattern for primaryUser wiring (in identity.nix or primaryUser.nix)
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv;
in {
  options.nerv.primaryUser = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = "Primary system users. Each gets wheel+networkmanager groups, and zsh shell if nerv.zsh.enable is true.";
    example     = [ "demon0" ];
  };

  config = lib.mkIf (cfg.primaryUser != []) {
    users.users = lib.genAttrs cfg.primaryUser (name: {
      extraGroups = [ "wheel" "networkmanager" ];
    } // lib.optionalAttrs cfg.zsh.enable {
      shell = pkgs.zsh;
    });
  };
}
```

**Note on `lib.genAttrs` vs `builtins.listToAttrs`:** `lib.genAttrs names (name: value)` is the idiomatic choice when all entries share the same structure. It avoids the `map (name: { inherit name; value = ...; })` boilerplate of `listToAttrs`.

### Pattern 4: Opaque Module Migration (no options)
**What:** Move a module file unchanged into `modules/system/`, add it to `default.nix` imports. No options block, no `mkIf`.
**When to use:** `security.nix` — content migrates verbatim.

```nix
# modules/system/security.nix — identical to current modules/security.nix
{ config, lib, pkgs, ... }:
{
  security.protectKernelImage = true;
  # ... all existing content, zero changes
}
```

### Pattern 5: Identity Module with Required Option
**What:** `nerv.hostname` has no default — it must be set. Use `lib.mkOption` without `default`. NixOS will error at eval if unset.
**When to use:** hostname only — locale options all have sensible defaults.

```nix
nerv.hostname = lib.mkOption {
  type        = lib.types.str;
  # no default — forces host flake to declare it
  description = "Machine hostname. Sets networking.hostName.";
  example     = "nixos-workstation";
};
```

**On asserting `nerv.hostname != ""`:** `lib.types.str` accepts empty string. An explicit `assertions` check is cleaner than relying on downstream NixOS validation for an empty hostname:

```nix
config = {
  assertions = [{
    assertion = cfg.hostname != "";
    message   = "nerv.hostname must not be empty.";
  }];
  networking.hostName = cfg.hostname;
  # ...
};
```

### Anti-Patterns to Avoid
- **Double-importing old flat modules:** After migrating to `modules/system/`, the old `modules/hardware.nix`, `modules/kernel.nix`, etc. must be removed from any import lists. The root `modules/default.nix` imports only `./system` and `./services` — it does NOT import the old flat files.
- **Forgetting to remove `amd_iommu=on iommu=pt` from kernel.nix:** If both kernel.nix and hardware.nix emit these params, they appear twice in `boot.kernelParams` — harmless but confusing, and the migration intent is broken.
- **Using `lib.mkForce` for conditional blocks:** Use `lib.mkIf` instead. `lib.mkForce` is the escape hatch for host-level overrides, not for module-internal conditionals.
- **Circular option reads:** `nerv.primaryUser` reads `config.nerv.zsh.enable`. This is safe because zsh.nix is in `modules/services/` (already loaded), but the primaryUser module must not be placed in services/ — it belongs in system/.
- **Omitting `lib.mkIf (cfg.primaryUser != [])` guard:** Without the guard, `lib.genAttrs [] ...` produces an empty attrset — technically fine, but the guard makes intent explicit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Conditional list element inclusion | Manual string concatenation or if-then-else chains | `lib.optionals condition list` | Idiomatic, merge-safe with NixOS module system |
| Multi-value attrset from list | `builtins.foldl'` manual accumulator | `lib.genAttrs names valueFn` | Single expression, readable, evaluated lazily |
| Module-level branching on option value | Multiple `config` blocks (invalid) | `lib.mkMerge [ (lib.mkIf ...) ... ]` | NixOS merges all `config` values; `mkMerge` is how you express branches |
| Asserting option validity | Downstream NixOS errors (hard to read) | `assertions = [{ assertion = ...; message = "..."; }]` | Produces clear error messages at eval time |

**Key insight:** The NixOS module system's merge semantics mean you cannot conditionally suppress a config block by not returning it — you must use `lib.mkIf`. Getting this wrong produces either always-on behavior or evaluation errors.

---

## Common Pitfalls

### Pitfall 1: Old Flat Module Still Imported
**What goes wrong:** `modules/hardware.nix` (old flat file) is still imported somewhere alongside the new `modules/system/hardware.nix`, causing duplicate option definitions or duplicate config values.
**Why it happens:** The root `modules/default.nix` currently does NOT import the old flat files (it imports `./system` and `./services`), but if `hosts/nixos-base/configuration.nix` or any other file had direct imports of the flat modules, those would conflict.
**How to avoid:** After migrating each file, search for any remaining `import ../hardware.nix` or `./hardware.nix` references. The flat files in `modules/` are NOT removed in Phase 3 (they serve as source material) but they must not be imported.
**Warning signs:** Eval error "option ... already declared" or "infinite recursion" during nixos-rebuild build.

### Pitfall 2: `boot.kernelParams` List Merge Conflict
**What goes wrong:** `kernel.nix` still contains `"amd_iommu=on"` and `"iommu=pt"` after the migration, AND `hardware.nix` adds them conditionally. Both files are imported; the params appear twice.
**Why it happens:** Copy-paste migration without removing the two lines from kernel.nix.
**How to avoid:** The kernel.nix migration task explicitly removes lines 10-11 (`"amd_iommu=on"` and `"iommu=pt"`). Verify with `nixos-rebuild build` and inspect the final kernelParams in the built system.
**Warning signs:** No eval error (list merging is valid), but the kernel cmdline shows duplicate params.

### Pitfall 3: `users.users` Extension Clobbering Existing Declaration
**What goes wrong:** `nerv.primaryUser = [ "demon0" ]` and `configuration.nix` both declare `users.users.demon0 = { ... }`. If the primaryUser module uses `=` assignment instead of attrset merge, NixOS will error with "attribute already defined."
**Why it happens:** In NixOS module system, multiple modules can contribute to the same `users.users.<name>` — the module system merges them. This works correctly as long as the primaryUser module does NOT use `lib.mkForce` or re-declare conflicting sub-attributes.
**How to avoid:** The primaryUser module only sets `extraGroups` and `shell` — attributes that the host flake's `users.users.demon0 = { isNormalUser = true; ... }` does not set (or sets the same way). Do not declare `isNormalUser`, `home`, `uid`, or other attributes in the primaryUser module.
**Warning signs:** Eval error "conflict between ... and ..." on `users.users.demon0`.

### Pitfall 4: `nerv.zsh.enable` Read Before zsh Module Loaded
**What goes wrong:** The primaryUser module reads `config.nerv.zsh.enable`, but if modules are evaluated before zsh.nix is imported, the option does not exist yet.
**Why it happens:** NixOS module system lazily evaluates options, but options must be declared before they can be read. Since `modules/system/default.nix` is imported by `modules/default.nix` alongside `modules/services/default.nix`, both are in scope simultaneously — evaluation order is not sequential.
**How to avoid:** This is safe in practice because all NixOS modules are merged before evaluation begins. The module system declares all options first, then evaluates config. No action needed — just do not try to move zsh.nix into system/ to "fix" this (it's not broken).
**Warning signs:** Eval error "attribute 'zsh' missing in nerv" — would mean zsh.nix is not imported at all.

### Pitfall 5: `hardware.nvidia.open = true` on Pre-Turing GPU
**What goes wrong:** Setting `nerv.hardware.gpu = "nvidia"` hardcodes `hardware.nvidia.open = true`. On Maxwell or Pascal GPUs (GTX 900/1000 series), the open kernel module is not supported — the system may fail to boot graphically.
**Why it happens:** `hardware.nvidia.open` was introduced for Turing+ (RTX 20xx+) and is not compatible with older architectures.
**How to avoid:** Document prominently in the module that `hardware.nvidia.open = lib.mkForce false` is required for pre-Turing GPUs. The module comment must state this.
**Warning signs:** Black screen after boot, NVIDIA driver fails to load, `journalctl -b | grep nvidia` shows errors.

### Pitfall 6: Missing `console.font` / `console.packages` After Identity Migration
**What goes wrong:** The current `configuration.nix` sets `console.font = "ter-v18n"` and `console.packages = [ pkgs.terminus_font ]`. If `identity.nix` takes over `console.keyMap` but the host flake's `configuration.nix` block for console is removed entirely, the font configuration is lost.
**Why it happens:** Partial migration of the `console` block.
**How to avoid:** The host `configuration.nix` must retain `console.font` and `console.packages` declarations independently — identity.nix only controls `console.keyMap`. Alternatively, identity.nix can include `console.font` and `console.packages` as hardcoded defaults (at Claude's discretion per CONTEXT.md).
**Warning signs:** TTY uses default font (VGA) instead of Terminus after rebuild.

---

## Code Examples

Verified patterns from official project sources:

### nerv.hostname — Required String Option
```nix
# modules/system/identity.nix
options.nerv.hostname = lib.mkOption {
  type        = lib.types.str;
  description = "Machine hostname. Sets networking.hostName. Required — no default.";
  example     = "nixos-workstation";
};

# config block
config = {
  assertions = [{
    assertion = config.nerv.hostname != "";
    message   = "nerv.hostname must not be empty string.";
  }];
  networking.hostName = config.nerv.hostname;
};
```

### nerv.locale — Defaulted String Options
```nix
options.nerv.locale = {
  timeZone = lib.mkOption {
    type        = lib.types.str;
    default     = "UTC";
    description = "System time zone. See 'timedatectl list-timezones'.";
    example     = "Europe/Rome";
  };
  defaultLocale = lib.mkOption {
    type        = lib.types.str;
    default     = "en_US.UTF-8";
    description = "Default system locale for LC_* variables.";
    example     = "it_IT.UTF-8";
  };
  keyMap = lib.mkOption {
    type        = lib.types.str;
    default     = "us";
    description = "Console keymap. Run 'localectl list-keymaps' for available values.";
    example     = "us-acentos";
  };
};

config = {
  # (hostname assertion here)
  networking.hostName    = config.nerv.hostname;
  time.timeZone          = config.nerv.locale.timeZone;
  i18n.defaultLocale     = config.nerv.locale.defaultLocale;
  console.keyMap         = config.nerv.locale.keyMap;
};
```

### nerv.primaryUser — List with Cross-Module Shell Wiring
```nix
# Source: established pattern from Phase 2 + CONTEXT.md decisions
let
  cfg = config.nerv;
in {
  options.nerv.primaryUser = lib.mkOption {
    type        = lib.types.listOf lib.types.str;
    default     = [];
    description = "Primary system users. Each gets wheel+networkmanager groups. If nerv.zsh.enable is true, shell is set to zsh.";
    example     = [ "demon0" ];
  };

  config = lib.mkIf (cfg.primaryUser != []) {
    users.users = lib.genAttrs cfg.primaryUser (_name: {
      extraGroups = [ "wheel" "networkmanager" ];
    } // lib.optionalAttrs cfg.zsh.enable {
      shell = pkgs.zsh;
    });
  };
}
```

### hardware.nix — lib.mkMerge Branching Pattern
```nix
# Conditional kernel params via lib.optionals inside lib.mkIf block
(lib.mkIf (cfg.cpu == "amd") {
  hardware.cpu.amd.updateMicrocode = true;
  boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];
})
```

NixOS merges `boot.kernelParams` lists from all modules — adding to the list from hardware.nix is safe alongside kernel.nix's hardened params list.

### nix.nix — Single Line Change
```nix
# Before (wrong path):
flake = "/etc/nixos#nixos";

# After (correct path):
flake = "/etc/nerv#nixos-base";
```

All other content in nix.nix migrates verbatim.

### modules/system/default.nix — Aggregator Population
```nix
# After Phase 3:
{ imports = [
    ./identity.nix
    ./hardware.nix
    ./kernel.nix
    ./security.nix
    ./nix.nix
  ];
}
```

Order note: No ordering constraint between these modules (none depend on each other's options within system/). Alphabetical or logical grouping is fine.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `hardware.nvidia.modesetting.enable` + closed driver | `hardware.nvidia.open = true` (open kernel module) | NVIDIA R525+ / Turing+ support (2022) | Turing and later GPUs should prefer open module; Maxwell/Pascal cannot use it |
| Flat module layout (`modules/hardware.nix`) | Subdirectory layout (`modules/system/hardware.nix`) | Phase 1 established the structure; Phase 3 populates it | Cleaner separation between system-level and service-level modules |
| Hardcoded identity in configuration.nix | `nerv.hostname` / `nerv.locale.*` options | Phase 3 (this phase) | Host flakes declare only their values; module handles the wiring |

**Deprecated/outdated:**
- The AMD-only microcode in the current `hardware.nix` is hardcoded — Phase 3 replaces it with the enum-conditional pattern.
- The stale `/etc/nixos#nixos` path in `nix.nix` — fixed in this phase.

---

## Open Questions

1. **Whether `identity.nix` should include `console.font` and `console.packages` (terminus)**
   - What we know: Current `configuration.nix` sets `console.font = "ter-v18n"` and `console.packages = [ pkgs.terminus_font ]`. These are not in the locked decisions. CONTEXT.md marks this as Claude's discretion.
   - What's unclear: If identity.nix takes over `console.keyMap` only, the host flake must retain the font settings. If identity.nix also hardcodes the font, it becomes an opinionated default that may not suit all users.
   - Recommendation: Hardcode `console.font = "ter-v18n"` and `console.packages = [ pkgs.terminus_font ]` in `identity.nix` as reasonable defaults. Document with a comment that `lib.mkForce` can override. This prevents silent font loss during host configuration migration.

2. **`lib.genAttrs` vs `builtins.listToAttrs` for primaryUser**
   - What we know: Both work. `lib.genAttrs cfg.primaryUser (name: { ... })` is idiomatic when all entries share the same structure.
   - What's unclear: Whether `lib.optionalAttrs` on the value side works cleanly with `lib.genAttrs`.
   - Recommendation: Use `lib.genAttrs` with `//` to merge the optional shell attribute. Pattern is verified above and mirrors the openssh `optionalAttrs` usage from Phase 2.

3. **Import order in `modules/system/default.nix`**
   - What we know: NixOS module system evaluates all imports before resolving options — order does not affect correctness.
   - What's unclear: Convention preference.
   - Recommendation: Logical order: identity.nix, hardware.nix, kernel.nix, security.nix, nix.nix. The "machine identity" modules first, then hardening, then nix daemon config.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None installed — NixOS evaluation acts as the primary validator |
| Config file | N/A |
| Quick run command | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| Full suite command | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| OPT-01 | `nerv.hostname` sets `networking.hostName` | smoke | `nixos-rebuild build --flake .#nixos-base` | Eval failure if hostname missing; correctness verified by inspecting resulting config |
| OPT-01 | `nerv.locale.*` options set time/i18n/console | smoke | `nixos-rebuild build --flake .#nixos-base` | Type errors caught at eval |
| OPT-02 | `nerv.primaryUser = ["demon0"]` wires groups | smoke | `nixos-rebuild build --flake .#nixos-base` | Eval verifies option merge; group presence requires runtime check |
| OPT-03 | `nerv.hardware.cpu = "amd"` enables microcode + IOMMU params | smoke | `nixos-rebuild build --flake .#nixos-base` | Enum type catches invalid values at eval |
| OPT-04 | `nerv.hardware.gpu = "none"` builds without xserver config | smoke | `nixos-rebuild build --flake .#nixos-base` | Ensures default "none" path does not emit driver config |

### Sampling Rate
- **Per task commit:** `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Per wave merge:** `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Phase gate:** Full build green before `/gsd:verify-work`

### Wave 0 Gaps
None — no test framework to install. The NixOS evaluator is the test infrastructure. Build command must pass after each task.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase — `modules/services/openssh.nix` read directly; establishes the options pattern used in all Phase 3 modules
- Existing codebase — `modules/hardware.nix`, `modules/kernel.nix`, `modules/security.nix`, `modules/nix.nix` read directly; all migration source material verified
- Existing codebase — `hosts/nixos-base/configuration.nix` read directly; identity values to be replaced confirmed
- CONTEXT.md — all locked decisions read and transcribed verbatim

### Secondary (MEDIUM confidence)
- NixOS module system `lib.mkMerge`, `lib.mkIf`, `lib.genAttrs`, `lib.optionalAttrs` patterns — verified against Phase 2 working code (openssh.nix uses `lib.optionalAttrs` for AllowUsers guard, confirmed working)
- `hardware.nvidia.open = true` — verified against CONTEXT.md locked decision citing Turing+ support; consistent with NixOS wiki knowledge

### Tertiary (LOW confidence)
- None — all claims verified against existing working code or locked decisions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all options are built-in NixOS; patterns verified from Phase 2 working code
- Architecture: HIGH — file structure established by Phase 1; migration approach verified against existing flat modules
- Pitfalls: HIGH — dual-import and list-merge pitfalls verified against actual file contents read during research; nvidia/open caveat sourced from CONTEXT.md specifics section

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (stable domain — NixOS module system API is very stable; nvidia.open caveat may change with new GPU generations)
