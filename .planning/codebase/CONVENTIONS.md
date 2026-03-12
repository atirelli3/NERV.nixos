# Coding Conventions

**Analysis Date:** 2026-03-12

## Naming Patterns

**Files:**
- Nix modules use lowercase with hyphens: `openssh.nix`, `pipewire.nix`, `hardware.nix`
- Directory names are lowercase: `modules/system/`, `modules/services/`, `hosts/`, `home/`
- Template files use lowercase: `hm-template/`
- Multi-word names use hyphens: `disko.nix`, `secureboot.nix`, `zsh.nix`

**Functions:**
- Nix expressions use camelCase for function parameters: `cfg`, `isBtrfs`, `isLvm`
- Binding names follow Nix conventions: short, descriptive lowercase with underscores for helper bindings
- Pattern: `let binding = expression; in { ... }` for local computations

**Variables:**
- Configuration references use dot notation: `config.nerv.hostname`, `config.nerv.disko.layout`
- Prefix commonly used config values: `cfg = config.nerv.*` (see all system and service modules)
- Boolean flags use clear predicates: `isBtrfs`, `isLvm`, `isSbctlPath`

**Types:**
- Nix type declarations are explicit: `lib.types.str`, `lib.types.bool`, `lib.types.enum [ "..." ]`
- Option types use precise enum constraints where appropriate: `lib.types.enum [ "btrfs" "lvm" ]` in `modules/system/disko.nix:38`
- Attribute set types: `lib.types.attrsOf (lib.types.attrsOf lib.types.str)` in `modules/system/impermanence.nix:64`

## Code Style

**Formatting:**
- No explicit formatter detected (not using prettier, biome, or similar)
- Manual formatting with consistent indentation (2 spaces)
- Long lines broken across multiple lines for readability
- Comments precede code blocks (not inline)

**Linting:**
- No linting configuration detected (.eslintrc, .prettierrc, biome.json absent)
- Style enforced through manual review and community conventions
- Code quality depends on human consistency

**Ordering:**
- File structure is consistent across all modules:
  1. File header comment (filename + description + profile cross-reference)
  2. Function signature with destructured arguments
  3. Optional `let` bindings for local computations
  4. `in` keyword with single expression (always an attrset)
  5. Config body with `options` defined first, then `config` implementation

Example from `modules/services/openssh.nix`:
```nix
# modules/services/openssh.nix
#
# SSH daemon hardened with endlessh tarpit and fail2ban. Disabled by default.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.openssh;
in {
  options.nerv.openssh = { ... };
  config = lib.mkIf cfg.enable { ... };
};
```

## Import Organization

**Module Imports:**
- System modules aggregated in `modules/system/default.nix` with explicit comments indicating dependencies
- Services aggregated in `modules/services/default.nix` with explicit enable flags
- Flake entry point `flake.nix` composes all modules with clear separation of concerns

**Path Aliases:**
- No explicit path aliases used
- Direct file imports via relative paths: `./identity.nix`, `./openssh.nix`
- Absolute paths for host-level imports in Home Manager: `imports = [ /home/${name}/home.nix ]` in `home/default.nix:44`

**Attribute Set Merging:**
- `lib.mkMerge [ ... ]` used for conditional configuration branches
- Single attrsets for unconditional config
- `lib.mkIf` guards conditional blocks: `lib.mkIf isBtrfs { ... }` (see `modules/system/disko.nix:73`)

## Error Handling

**Assertions:**
- NixOS assertions used for configuration validation
- Checked at evaluation time before system build
- Pattern: `assertions = [{ assertion = condition; message = "error message"; }]`
- Example in `modules/services/openssh.nix:48-51`:
```nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```
- Complex assertion in `modules/system/impermanence.nix:74-85` validates sbctl path conflicts

**Fallback Values:**
- Default values specified in option declarations: `default = 2222;` in `modules/services/openssh.nix:15`
- Placeholder defaults for mandatory options: `default = "PLACEHOLDER";` in `modules/system/disko.nix:51` (forces explicit user configuration)
- Conditional fallbacks using `lib.optionalAttrs`: see `modules/system/identity.nix:65` for optional zsh shell assignment

## Logging

**Framework:** Nix has no runtime logging mechanism; all logging happens at system level via systemd services

**Patterns:**
- Configuration-time output via `lib.mkMerge` tracing (hidden unless `--show-trace` is used)
- Runtime logging delegated to systemd services and journalctl
- System logs written via `systemd.services.<name>.serviceConfig.ExecStart` scripts
- Example: audit rules loaded in `modules/system/security.nix:27-51` with service output to journal
- AIDE check results logged to journal: `journalctl -u aide-check` (see `modules/system/security.nix:112`)

**Script Logging:**
- Shell scripts within `pkgs.writeShellScript` use `echo` or direct output
- Example in `modules/system/disko.nix:123-133` rollback service outputs to initrd logs
- `echo` statements used in zsh initialization script (`modules/services/zsh.nix:98-143`)

## Comments

**When to Comment:**
- File header required at top: filename, description, and relevant profile/mode information
- Section headers use `# ── Section Name ────────` (80-character lines with visual separator)
- Inline comments explain non-obvious decisions and workarounds
- TODO/FIXME comments rare; none detected in codebase

**JSDoc/TSDoc:**
- Not applicable (Nix language, not TypeScript/JavaScript)
- Option descriptions use Nix multiline strings with `''...'` syntax
- Example from `modules/system/identity.nix:10-44`:
```nix
options.nerv.hostname = lib.mkOption {
  type        = lib.types.str;
  description = "Machine hostname. Sets networking.hostName. Required — no default.";
  example     = "nixos-workstation";
};
```

**Multiline Descriptions:**
- Use triple-quoted strings for detailed option documentation
- Example from `modules/system/impermanence.nix:37-46`:
```nix
description = ''
  Impermanence mode.
    btrfs — Root stays on BTRFS @; rollback service resets @ on each boot...
    full  — / as tmpfs (resets on reboot); /persist holds system state via...
  Intentionally no default — forces explicit declaration per host;
  consistent with nerv.disko.layout and nerv.hostname.
'';
```

## Function Design

**Size:** Functions (let bindings) are typically single expressions composed with built-in NixOS/nixpkgs functions

**Parameters:**
- Module parameters always destructured: `{ config, lib, pkgs, ... }`
- `...` used to ignore unused parameters
- Discriminated parameters in `let` bindings for clarity: `cfg = config.nerv.*` binds frequently-used values

**Return Values:**
- All modules return a single attrset: `{ options = {...}; config = {...}; }`
- Conditional returns wrapped in `lib.mkIf`: returns the attrset only if condition is true
- Merged configs use `lib.mkMerge [ { ... } { ... } ]` for multiple conditional branches
- No explicit error returns; invalid configs caught by assertions before evaluation completes

## Module Design

**Exports:**
- Flake modules exported via `nixosModules` attrset in `flake.nix:65-72`
- Granular exports enable selective composition: `default`, `system`, `services`, `home`
- Each module self-contained; no cross-module function exports

**Barrel Files:**
- `modules/system/default.nix` and `modules/services/default.nix` aggregate their children
- Simple re-export pattern: `{ imports = [ ./file1.nix ./file2.nix ]; }`
- Matches NixOS module composition conventions

**Option Naming:**
- All custom options scoped under `nerv.*`: `nerv.hostname`, `nerv.disko.layout`, `nerv.openssh.enable`
- Prevents namespace pollution and makes custom options easily identifiable
- Nested options for related functionality: `nerv.disko.lvm.swapSize`, `nerv.locale.timeZone`

## Conditional Configuration

**lib.mkIf Pattern:**
- Used to conditionally enable/disable entire module blocks based on enable flags
- Example: `config = lib.mkIf cfg.enable { ... }` in `modules/services/openssh.nix:47`
- Nested conditions for complex logic: `(lib.mkIf (cfg.cpu == "amd") { ... })` in `modules/system/hardware.nix:43`

**lib.mkMerge Pattern:**
- Used to combine multiple conditional branches into one attrset
- Returns list of attrsets that are merged in order
- Example from `modules/system/disko.nix:70-191` with BTRFS and LVM branches

**lib.mkForce Pattern:**
- Override inherited values: `boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;` in `modules/system/kernel.nix:10`
- Used when a module needs to enforce a value against defaults
- Comments indicate when users should override with `lib.mkForce` if needed (e.g., in `modules/system/hardware.nix:55`)

**lib.optionalAttrs Pattern:**
- Conditionally add attributes: `{ shell = pkgs.zsh; } // lib.optionalAttrs config.nerv.zsh.enable { ... }`
- Example in `modules/system/identity.nix:63-67` for optional zsh shell assignment per user

---

*Convention analysis: 2026-03-12*
