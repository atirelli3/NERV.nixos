# Coding Conventions

**Analysis Date:** 2026-03-10

## Language Context

This is a pure Nix/NixOS codebase. All source files are `.nix`. There is no JavaScript, TypeScript, Python, or other scripting language. Conventions below are specific to the Nix expression language and NixOS module system.

## File Header Convention

Every `.nix` file opens with a comment block stating the module's path and a one-line purpose summary:

```nix
# modules/system/boot.nix
#
# Layout-agnostic initrd and bootloader (systemd-boot + EFI). Layout-specific initrd config lives in disko.nix.
```

Pattern: `# <relative-path-from-repo-root>` on line 1, `#` blank line, `# <one-sentence description>` on line 3.

## Module Function Signatures

All NixOS modules use the full destructured argument list, even when not all args are used:

```nix
{ config, lib, pkgs, ... }:
```

Opaque modules (no options defined, only config) omit unused args:

```nix
{ pkgs, ... }:   # boot.nix — no options, only pkgs needed
{ config, lib, pkgs, ... }:  # modules with options always include all three
```

## Naming Patterns

**Files:**
- `kebab-case.nix` for module files: `openssh.nix`, `secureboot.nix`, `pipewire.nix`
- `default.nix` for aggregator/index files at each directory level

**Option namespaces:**
- All custom options live under `nerv.*`: `nerv.hostname`, `nerv.openssh.enable`, `nerv.disko.layout`
- Sub-namespaces match the module filename: `openssh.nix` → `nerv.openssh.*`, `disko.nix` → `nerv.disko.*`
- Boolean toggles use `lib.mkEnableOption` for disabled-by-default: `lib.mkEnableOption "PipeWire audio stack"`
- Boolean options that default to `true` use explicit `lib.mkOption { type = lib.types.bool; default = true; }` (see `zsh.nix`, `home/default.nix`)

**Local config binding:**
- Always bind `config.nerv.<module>` to `cfg` at the top of the `let` block:
  ```nix
  let
    cfg = config.nerv.openssh;
  in
  ```
- Layout booleans extract to named predicates: `isBtrfs = cfg.layout == "btrfs";`

**Subvolume names:**
- BTRFS subvolumes use `@`-prefix convention: `/@`, `/@home`, `/@nix`, `/@persist`, `/@log`, `/@root-blank`

**Disk labels:**
- UPPERCASE: `NIXLUKS`, `NIXBTRFS`, `NIXBOOT`, `NIXSTORE`, `NIXSWAP`, `NIXPERSIST`

## Option Declarations

Options follow a consistent four-field layout with aligned columns:

```nix
lib.mkOption {
  type        = lib.types.str;
  default     = "UTC";
  description = "System time zone. See 'timedatectl list-timezones'.";
  example     = "Europe/Rome";
};
```

- `type`, `default`, `description`, `example` — always in this order
- Column-aligned with spaces (not tabs)
- `description` ends with a period and includes usage guidance where needed
- Options intentionally without defaults (forcing explicit declaration) omit the `default` field and document this in the description: `"intentionally no default — forces explicit declaration per host"`
- `lib.mkEnableOption` is used for simple boolean on/off options that default `false`

## Config Blocks

**Guard pattern:** All configurable modules wrap their `config` block in `lib.mkIf cfg.enable`:

```nix
config = lib.mkIf cfg.enable {
  ...
};
```

**Multi-branch pattern:** Conditional layout logic uses `lib.mkMerge` with `lib.mkIf` per branch:

```nix
config = lib.mkMerge [
  (lib.mkIf isBtrfs { ... })
  (lib.mkIf isLvm   { ... })
  { ... }  # unconditional shared config at the end
];
```

**Merged identity + conditional:** When a module has both unconditional config and conditional sections:

```nix
config = lib.mkIf cfg.enable (lib.mkMerge [
  { ... }                                # unconditional when enabled
  (lib.mkIf (cfg.mode == "full")  { ... })
  (lib.mkIf (cfg.mode == "btrfs") { ... })
]);
```

## Aggregator Modules

Aggregator `default.nix` files are minimal one-liners:

```nix
# modules/default.nix
#
# Top-level aggregator — imports system, services, and home module subtrees.
{ imports = [ ./system ./services ../home ]; }
```

No options, no config logic. Only an `imports` list.

## Alignment and Formatting

- Attrset values are column-aligned when grouped by logical purpose:
  ```nix
  nerv.disko.layout         = "btrfs";
  nerv.openssh.enable       = true;
  nerv.audio.enable         = true;
  nerv.bluetooth.enable     = true;
  ```
- Option declarations use consistent 8-space column alignment for `type`, `default`, `description`, `example`
- Single-line attrsets for trivial configs; multi-line with alignment for 3+ keys

## Assertions

Validation assertions follow a two-field pattern in the `assertions` list:

```nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

- `message` always prefixed with `"nerv: "` or `"nerv.<module>: "` for attribution
- `lib.optional` used when assertion is itself conditional:
  ```nix
  assertions = lib.optional config.nerv.secureboot.enable { ... };
  ```

## Warnings

Recoverable issues use `lib.warn` (not `assertions`) to preserve `nix flake check` during migrations:

```nix
warnings =
  lib.optionals (config.nerv.secureboot.enable && !sbctlCovered)
    [ "nerv: secureboot is enabled but /var/lib/sbctl is not covered by environment.persistence..." ];
```

## Overrides

- `lib.mkForce` is used only when a downstream module must override a setting from an upstream module (e.g., `secureboot.nix` sets `boot.loader.systemd-boot.enable = lib.mkForce false`)
- `lib.mkDefault` is used for settings that callers should be able to override:
  ```nix
  fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;
  ```

## Shell Scripts Embedded in Nix

Scripts inside `serviceConfig.script` or `pkgs.writeTextFile` blocks:

- Include step-by-step inline comments
- Use idempotency guards with sentinel files (`/var/lib/secureboot-keys-enrolled`)
- Always include `|| true` on `btrfs subvolume delete` to prevent initrd failures
- Reference packages via `${pkgs.<package>}/bin/<binary>` rather than bare names

## Comments

- Inline comments on same line for brief clarifications: `# required for boot.initrd.systemd.services.*`
- Block comments above logical groups with `# ── Section Name ────` decorators:
  ```nix
  # ── BTRFS branch ─────────────────────────────────────────────────────
  ```
- Cross-module sync notes use `# must stay in sync with <file>` or `# must match <file> and <file>`
- "Intentional" decisions documented inline to prevent future "cleanup" reversions:
  ```nix
  # intentionally no default — forces explicit declaration per host
  ```
- Commented-out optional config is preserved with explanatory comments (e.g., jackd support in `pipewire.nix`, disabled plugins in `zsh.nix`)

## Error Handling

NixOS modules have no runtime error handling — all validation is at evaluation time:
- Type errors caught by `lib.types.*` declarations (evaluated at `nixos-rebuild` time)
- Logic errors caught by `assertions` (evaluated at `nixos-rebuild` time)
- Recoverable conditions use `warnings` (display-only, build continues)
- Hard invariants use `assertions` (build fails)

## Module Opacity Levels

Modules are explicitly categorised in their header comments:
- **"Fully opaque"** — no user-facing options; use `lib.mkForce` to override: `nix.nix`, `kernel.nix`, `security.nix`
- **"Always-on"** — activated unconditionally, no enable toggle: `packages.nix`, `security.nix`
- **"Disabled by default"** — require explicit `enable = true`: `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, `secureboot.nix`, `impermanence.nix`
- **"Enabled by default"** — active unless overridden: `zsh.nix`, `home/default.nix`

## Import / Module Structure

- `imports` lists in `default.nix` aggregators always reference files without `.nix` extension for directories: `./system`, `./services`
- Explicit load order enforced via comments where it matters: `# secureboot.nix must be last`
- Cross-module references are explicit: `config.nerv.zsh.enable` accessed from `identity.nix`

---

*Convention analysis: 2026-03-10*
