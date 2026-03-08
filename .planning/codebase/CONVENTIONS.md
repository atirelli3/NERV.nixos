# Coding Conventions

**Analysis Date:** 2026-03-08

## Language

This is a pure Nix codebase — all source files use the Nix expression language (`.nix`). There is no TypeScript, Python, or other general-purpose language. Conventions apply to Nix idioms and NixOS module authoring.

## File Header Comments

Every `.nix` file begins with a structured block comment. This is mandatory — treat it as a file-level docstring.

**Pattern (service modules with options):**
```nix
# modules/services/openssh.nix
#
# Purpose  : SSH daemon hardened with endlessh tarpit and fail2ban.
# Options  : nerv.openssh.enable, nerv.openssh.port, nerv.openssh.tarpitPort, ...
# Defaults : enable = false; port = 2222; tarpitPort = 22; ...
# Override : lib.mkForce on any services.openssh.* or services.fail2ban.* setting.
# Note     : Port 22 is reserved for the endlessh tarpit. Connect with ssh -p <port>.
```

**Pattern (opaque modules with no options):**
```nix
# modules/system/kernel.nix
#
# Purpose : Kernel selection and generic hardening parameters.
# Options : None — fully opaque. Use lib.mkForce to override any setting.
# Note    : CPU-specific IOMMU params live in hardware.nix ...
```

**Pattern (aggregator default.nix):**
```nix
# modules/system/default.nix
#
# Purpose  : Aggregates all nerv system modules.
# Modules  : identity, hardware, kernel, security, nix, packages, boot, impermanence, secureboot
# Note     : secureboot.nix must be last — it applies lib.mkForce false on systemd-boot ...
```

**Fields used (aligned with spaces, not tabs):**
- `Purpose` — one-line description of the module's responsibility
- `Options` — list of all `nerv.*` options declared (or "None")
- `Defaults` — default values for key options
- `Override` — how a consumer can escape hardcoded settings
- `Note` — cross-cutting concerns, import order requirements, caveats

## Naming Patterns

**Files:**
- `kebab-case.nix` — all module files use lowercase kebab-case: `openssh.nix`, `disko-configuration.nix`, `hardware-configuration.nix`
- `default.nix` — aggregator files at each directory level import their siblings

**NixOS options namespace:**
- All custom options live under `nerv.*`: `nerv.openssh.enable`, `nerv.hardware.cpu`, `nerv.impermanence.mode`
- Sub-namespace for feature-specific options: `nerv.locale.timeZone`, `nerv.impermanence.persistPath`
- Boolean toggles always use `lib.mkEnableOption`: `nerv.openssh.enable`, `nerv.bluetooth.enable`

**Local config alias:**
- Always bind `config.nerv.<feature>` to a local `cfg` binding at the top of the `let` block:
  ```nix
  let
    cfg = config.nerv.openssh;
  in { ... }
  ```
- Exception: `modules/system/identity.nix` uses `cfg = config.nerv` when accessing multiple top-level nerv attrs.

**Nix let bindings:**
- `camelCase` for computed local bindings: `extraDirFileSystems`, `userFileSystems`, `userTmpfilesRules`, `luksDevice01`

**Flake-level let bindings:**
- `camelCase` for profile attrsets: `hostProfile`, `serverProfile`, `vmProfile`

## Module Structure Pattern

Every service/system module follows this exact layout:

```nix
# <path/to/file.nix>
# <header comment block>

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.<feature>;
in {
  options.nerv.<feature> = {
    enable = lib.mkEnableOption "<description>";
    <option> = lib.mkOption {
      type        = lib.types.<type>;
      default     = <value>;
      description = "<description>";
      example     = <value>;
    };
  };

  config = lib.mkIf cfg.enable {
    <nixos settings>
  };
}
```

**Opaque modules** (no user-facing options, always-on) omit the `options` block and `let cfg` binding:
```nix
{ config, lib, pkgs, ... }:
{
  <nixos settings>
}
```

**Multi-condition modules** use `lib.mkMerge` for multiple conditional blocks:
```nix
config = lib.mkMerge [
  { <unconditional settings> }
  (lib.mkIf (cfg.cpu == "amd") { <amd-specific> })
  (lib.mkIf (cfg.cpu == "intel") { <intel-specific> })
];
```

## Option Declarations

**Standard option with all fields (align with spaces):**
```nix
port = lib.mkOption {
  type        = lib.types.port;
  default     = 2222;
  description = "Port the SSH daemon listens on. ...";
  example     = 2222;
};
```

- Field alignment: `type`, `default`, `description`, `example` — padded to align the `=` signs.
- `description` is always a string (single or multi-line with `''`), never omitted.
- `example` is always present unless the option uses `lib.mkEnableOption` (which provides its own).
- Types use `lib.types.*` fully qualified: `lib.types.port`, `lib.types.listOf lib.types.str`, `lib.types.enum [ "amd" "intel" "other" ]`, `lib.types.attrsOf (lib.types.attrsOf lib.types.str)`.

## Assertions Pattern

Use `assertions` inside `config` blocks to enforce invariants at build time:

```nix
config = lib.mkIf cfg.enable {
  assertions = [{
    assertion = cfg.tarpitPort != cfg.port;
    message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
  }];
  ...
};
```

- `assertion` holds the boolean expression that must be true.
- `message` uses string interpolation to include actual values, giving actionable error output.
- `lib.optional` is used when assertions are themselves conditional: `assertions = lib.optional config.nerv.secureboot.enable { ... };`

## Inline Comments Style

**Inline comments on settings** (after `=`) use `#` with a single space, placed to the right:
```nix
alsa.support32Bit = true; # needed for 32-bit apps (e.g. Steam, Wine)
pulse.enable = true;      # PulseAudio compatibility layer
```

**Section dividers in large attrsets** use `# ── Section ──...──`:
```nix
# ── Network ──────────────────────────────────────────────────────────────
```

**Explanatory comments** precede the setting they describe:
```nix
# Allows PipeWire to acquire realtime scheduling priority.
security.rtkit.enable = true;
```

**Cross-reference comments** point to related files:
```nix
# NIXLUKS label must stay in sync with disko-configuration.nix and secureboot.nix
```

## Override Pattern

Every module documents its escape hatch. The convention is `lib.mkForce` at the consuming host flake level:

- Opaque modules include `# Options : None — fully opaque. Use lib.mkForce to override any setting.`
- Service modules include `# Override : lib.mkForce on any services.<name>.* setting.`
- Where `lib.mkForce` is used internally (e.g., `secureboot.nix` forces `systemd-boot.enable = false`), the reason is always commented.

## Aggregator Pattern (default.nix)

Each directory has a `default.nix` that only contains an `imports` list — no logic:

```nix
# modules/services/default.nix
#
# Purpose  : Aggregates all nerv service modules.
{ imports = [
    ./openssh.nix
    ./pipewire.nix
    ./bluetooth.nix
    ./printing.nix
    ./zsh.nix
  ];
}
```

Import order is significant when documented (see `modules/system/default.nix` — `secureboot.nix` must be last).

## Profiles Pattern (flake.nix)

Named configuration profiles are `let` bindings in `flake.nix` — plain attrsets of `nerv.*` option assignments. All options use explicit aligned assignment:

```nix
hostProfile = {
  nerv.openssh.enable       = true;
  nerv.audio.enable         = true;
  nerv.bluetooth.enable     = true;
  nerv.printing.enable      = true;
  nerv.secureboot.enable    = false;
  nerv.impermanence.enable  = true;
  nerv.impermanence.mode    = "minimal";
  nerv.zsh.enable           = true;
  nerv.home.enable          = true;
};
```

- All `enable` values are explicit (`true` or `false`), never omitted.
- Attrset values are column-aligned using spaces.

## Host Configuration (hosts/configuration.nix)

Host-specific files declare only machine-specific values. All placeholder values use the string `"PLACEHOLDER"` (uppercase) to signal mandatory customization:

```nix
nerv.hostname    = "PLACEHOLDER";   # e.g. "my-desktop"
nerv.primaryUser = [ "PLACEHOLDER" ]; # e.g. [ "alice" ]
```

Comments on PLACEHOLDER lines include an inline example: `# e.g. "my-desktop"`.

## lib Usage

- Prefer `lib.mkIf` over manual `if ... then ... else {}` in `config` blocks.
- Use `lib.mkMerge` for multiple independent conditional blocks in one `config`.
- Use `lib.mkDefault` for values the user should be able to override without `mkForce`.
- Use `lib.mkForce` only when lower-priority declarations must be suppressed (e.g., disabling systemd-boot for lanzaboote).
- `lib.optionalAttrs` for conditionally including attrset keys: `lib.optionalAttrs (cfg.allowUsers != []) { AllowUsers = ...; }`.
- `lib.optional` for conditionally including list items.
- `builtins.*` functions (e.g., `builtins.listToAttrs`, `builtins.map`) are used directly without `lib.*` prefix.

## Formatting

- No automated formatter detected (no `nixfmt`, `alejandra`, or `treefmt` config files present).
- Indentation: 2 spaces throughout.
- Attribute alignment: spaces used to align `=` signs within related groups of attributes.
- Opening braces on the same line: `options.nerv.openssh = {`.
- Closing braces on their own line at the matching indentation level.
- Lists with one item per line when list has more than ~2 elements.

---

*Convention analysis: 2026-03-08*
