# Coding Conventions

**Analysis Date:** 2026-03-10

## Language

This is a pure Nix codebase. All files are `.nix`. No TypeScript, Python, or other general-purpose languages are present. Conventions described here are specific to Nix module authoring in the NixOS ecosystem.

## File Header Block

Every module file begins with a structured comment header. This is the primary documentation mechanism. Use this exact format:

```nix
# modules/services/example.nix
#
# Purpose  : One-line description of what this module does.
# Options  : nerv.example.enable, nerv.example.optionName
# Defaults : enable = false; optionName = "default"
# Override : lib.mkForce on any affected NixOS option path.
# Note     : Any caveats, ordering requirements, or cross-module dependencies.
```

Fields in use across all modules:
- `Purpose` — always present, one line
- `Options` — lists all declared `options.nerv.*` paths
- `Defaults` — states the default value of each option
- `Override` — documents the escape hatch pattern (`lib.mkForce`)
- `Note` — optional; used for cross-module dependencies, load-order constraints, or operational caveats
- `Profiles` — used in `disko.nix`, `impermanence.nix`, `boot.nix` to describe which `flake.nix` profile activates the module

Examples: `modules/services/openssh.nix`, `modules/system/impermanence.nix`, `modules/system/disko.nix`

## Module Structure

Every NixOS module follows this three-section layout:

```nix
# <file header>

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.<module>;
in {
  options.nerv.<module> = { ... };

  config = lib.mkIf cfg.enable { ... };
}
```

**Rules:**
- The `let cfg = config.nerv.<module>;` binding is always present and always named `cfg`.
- Options are declared under the `nerv.*` namespace exclusively. No top-level or foreign namespacing.
- Config is always guarded by `lib.mkIf cfg.enable { ... }` for optional modules.
- Fully opaque modules (no options) use bare attrset `{ ... }` for `config`, not `lib.mkIf`. Examples: `modules/system/nix.nix`, `modules/system/security.nix`, `modules/system/boot.nix`.
- `lib.mkMerge [ ... ]` is used when config needs to be split across multiple conditional branches. Example: `modules/system/impermanence.nix`, `modules/system/hardware.nix`, `modules/system/disko.nix`.

## Naming Patterns

**Options:**
- Enable flags: `lib.mkEnableOption "<description>"` — the description is the human-readable label shown in documentation.
- Sub-namespace grouping: `nerv.openssh.port`, `nerv.locale.timeZone`, `nerv.disko.lvm.swapSize`.
- Boolean options beyond enable: explicit `lib.mkOption` with `type = lib.types.bool`.

**Module files:**
- `kebab-case.nix` — all lowercase, hyphens. Examples: `openssh.nix`, `secureboot.nix`, `hardware.nix`.

**Internal let bindings:**
- `cfg` — always the config alias.
- Derived attrsets built in `let`: named descriptively, camelCase. Examples: `sharedEsp`, `sharedLuksOuter`, `extraDirFileSystems`, `userFileSystems`, `userTmpfilesRules`.
- Boolean convenience bindings: `isBtrfs`, `isLvm` in `disko.nix`.

**Aggregator files:**
- Always named `default.nix`. Every subdirectory has one. Examples: `modules/default.nix`, `modules/system/default.nix`, `modules/services/default.nix`.

## Option Declarations

Declare options with all four fields consistently:

```nix
lib.mkOption {
  type        = lib.types.str;
  default     = "UTC";
  description = "Human-readable description. Include example commands or caveats.";
  example     = "Europe/Rome";
}
```

- Align the field names with spaces so values start in the same column.
- Use `lib.types.enum [ "a" "b" ]` for constrained string options (not `str` with runtime checks).
- Intentionally omit `default` when the value must be set explicitly per host. Always document this with `# intentionally no default` and an explanation. Examples: `nerv.disko.layout`, `nerv.impermanence.mode`, `nerv.hostname`.
- Use `lib.mkEnableOption` (not `lib.mkOption { type = bool; default = false; }`) for all feature toggles.

## Assertions

Use `assertions` to enforce invariants that cannot be expressed in the type system:

```nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

- Place assertions inside `config = lib.mkIf cfg.enable { ... }` so they only fire when the module is enabled.
- Use `lib.optional` to conditionally include assertions: `assertions = lib.optional config.nerv.secureboot.enable { ... }`.
- Prefer `assertions` for hard invariants; use `warnings` for recoverable misconfigurations (see `impermanence.nix` btrfs/sbctl check).

## Warnings

Use `lib.warn` / `warnings` for recoverable issues that should not block builds:

```nix
warnings =
  lib.optionals (condition)
    [ "nerv: descriptive message about what to fix." ];
```

Example: `modules/system/impermanence.nix` lines 168–176 — warns when sbctl persistence is missing in btrfs mode, but does not fail the build.

## Conditional Config (lib.mkIf / lib.mkMerge)

- `lib.mkIf <condition> { ... }` — use for single-condition branches.
- `lib.mkMerge [ ... ]` — use when multiple independent conditional blocks need to be merged.
- `lib.optionalAttrs <condition> { ... }` — use for conditional inline attrset extension (e.g., adding `AllowUsers` only when non-empty in `openssh.nix`).
- `lib.optional <condition> value` — use for conditional list elements.
- The `//` operator is used only for static attrset merges in `let` bindings, not inside `config` (use `lib.mkMerge` there).

## Override Pattern

All opaque settings document the escape hatch explicitly:

```
# Override : lib.mkForce on any services.openssh.* or services.fail2ban.* setting.
```

`lib.mkForce` is used inside modules only when a lower-priority default must be superseded — the canonical case is `secureboot.nix` forcibly disabling `systemd-boot` when Lanzaboote takes over:

```nix
boot.loader.systemd-boot.enable = lib.mkForce false;
```

`lib.mkDefault` is used for values that should yield to any explicit host-level setting:

```nix
fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;
```

## Comment Style

- Inline comments: `# lowercase prose — explain why, not what.`
- Section separators in long files: `# ── Section Title ──────────────────────...`
- Cross-reference comments: `# must match <other-file> and <other-option>` to document synchronization requirements.
- Commented-out code that is intentionally retained as a user-facing template is always accompanied by an explanatory comment. Example: `jack.enable = true; # uncomment to enable JACK compatibility`.

## Inline Configuration Labels

Disk and LUKS labels are ALLCAPS (`NIXLUKS`, `NIXBTRFS`, `NIXBOOT`, `NIXSWAP`, `NIXSTORE`, `NIXPERSIST`). Cross-file synchronization is documented inline with `# must stay in sync with <file>`.

## Aggregator Modules (default.nix)

Aggregators contain only `{ imports = [ ... ]; }`. No logic. Import order is significant and documented when it matters:

```nix
# Note : secureboot.nix must be last — it applies lib.mkForce false on systemd-boot
#        to prevent conflict with Lanzaboote. Import order is significant.
```

Example: `modules/system/default.nix`

## Host Configuration (configuration.nix)

`hosts/configuration.nix` is the only file that holds machine-specific values. It uses `PLACEHOLDER` as the literal sentinel for all values that must be replaced before first boot. No logic lives here — only option assignments.

## Profile Pattern (flake.nix)

`flake.nix` defines named `let` bindings (`hostProfile`, `serverProfile`) as plain attrsets of option assignments. These are passed directly as NixOS modules. No helper functions or abstractions are used at the flake level.

## Alignment

Attribute assignments in attrsets use column-aligned `=` signs when multiple related options appear together:

```nix
nerv.disko.layout         = "btrfs";
nerv.openssh.enable       = true;
nerv.audio.enable         = true;
nerv.bluetooth.enable     = true;
```

This applies in `flake.nix` profiles and `hosts/configuration.nix`.

---

*Convention analysis: 2026-03-10*
