# Phase 2: Services Reorganization - Research

**Researched:** 2026-03-06
**Domain:** NixOS options module pattern; service module migration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- `nerv.openssh.enable = true` is required to activate SSH — off by default, consistent with audio/bluetooth/printing
- Default SSH port: **2222** (matches current behavior; port 22 is reserved for the endlessh tarpit)
- Endlessh (tarpit) and fail2ban are **always-on** when `nerv.openssh.enable = true` — no opt-out
- `nerv.openssh.tarpitPort` option (default: 22) — exposed because the tarpit port is conceptually coupled to the SSH port choice
- fail2ban settings (maxretry, bantime, bantime-increment, ignoreIP private subnets, sshd aggressive jail) are **hardcoded opinionated defaults** — not exposed as options; host flakes can override via `lib.mkForce` if needed
- `printing.nix` owns `avahi.enable = true` itself — self-contained, no dependency on audio
- `bluetooth.nix` also sets `avahi.enable = true` (for BT service advertisement via mDNS); NixOS merges duplicate `avahi.enable = true` cleanly
- bluetooth.nix wireplumber codec config is included unconditionally — no `mkIf` guard needed because PipeWire being disabled makes it a no-op
- **Remove from zsh.nix:** starship prompt configuration and NerdFont declarations (belong in user's home.nix)
- **Keep in zsh.nix:** zsh enable, autosuggestions, syntax-highlighting (manually sourced), history-substring-search, all keybindings, fzf integration, all shell aliases, sudo-widget
- Nix aliases (nrs, nrb, nrt, nfu, ngc, etc.) are **hardcoded to `/etc/nerv#nixos-base`** — no option to configure
- `secureboot.nix` is NOT migrated in Phase 2 — it is a Phase 4 concern

### Claude's Discretion

- Exact NixOS options module structure (mkOption types, descriptions, example values)
- Whether `nerv.openssh` uses a sub-attribute set or flat attribute names
- Whether to add assertion errors (e.g., assert tarpitPort != port) for obvious misconfigurations
- Order of imports in `modules/services/default.nix`

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OPT-05 | User can set `nerv.openssh.allowUsers` (list of strings, default empty = all) to restrict SSH access without risking a full lockout | NixOS `types.listOf types.str` maps directly to `services.openssh.settings.AllowUsers` |
| OPT-06 | User can set `nerv.openssh.passwordAuth` and `nerv.openssh.kbdInteractiveAuth` (both default `false`) to adjust SSH auth policy | NixOS `types.bool` maps to `services.openssh.settings.PasswordAuthentication` / `KbdInteractiveAuthentication` |
| OPT-07 | User can set `nerv.openssh.port` (default `2222`) to change the SSH listener port | NixOS `types.port` maps to `services.openssh.ports`; also must update `services.fail2ban.jails.sshd.settings.port` |
| OPT-08 | User can enable/disable audio, bluetooth, printing, and secureboot independently via `nerv.audio.enable`, `nerv.bluetooth.enable`, `nerv.printing.enable`, `nerv.secureboot.enable` (all default `false`) | NixOS `types.bool` with `mkIf cfg.enable` guard pattern |
</phase_requirements>

---

## Summary

Phase 2 is a code migration and wrapping exercise with no new external dependencies. Every module file being migrated already exists in `modules/`; the work is to move each file into `modules/services/`, wrap its body in the NixOS module options pattern (`options` + `config` + `mkIf`), and register each new file in `modules/services/default.nix`. All decisions about which options to expose and their defaults are locked in CONTEXT.md.

The NixOS options module pattern is the core technical domain. The pattern is well-documented in NixOS source and is stable: define `options.nerv.*` attributes using `lib.mkOption`, consume them in a `config = lib.mkIf cfg.enable { ... }` block. This is the same pattern used throughout nixpkgs and is the established convention for NixOS modules. Confidence is HIGH because the pattern is pulled directly from NixOS source, not from web search.

The critical sequencing constraint is that `modules/services/default.nix` must import each migrated file, and `hosts/nixos-base/configuration.nix` must be updated to set `nerv.*` options instead of depending on old flat module files. Build verification (`nixos-rebuild build --flake .#nixos-base`) must pass after each module migration to confirm no evaluation errors were introduced.

**Primary recommendation:** Migrate one module at a time in dependency order (openssh first as the most complex, then the enable-only services), verify build after each, then update `modules/services/default.nix` and `configuration.nix` together at the end.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `lib.mkOption` | NixOS stdlib | Declare typed options in modules | The canonical way to define options in any NixOS module |
| `lib.mkIf` | NixOS stdlib | Conditionally apply config when option is enabled | Standard guard pattern; avoids setting services when disabled |
| `lib.types.*` | NixOS stdlib | Type-check option values at evaluation time | Catches user errors before build; used throughout nixpkgs |
| `lib.mkEnableOption` | NixOS stdlib | Shorthand for a `types.bool` option defaulting to `false` | Saves boilerplate for enable flags; used in 90%+ of nixpkgs modules |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `lib.mkDefault` | NixOS stdlib | Set a default that host flakes can override with `mkForce` | For values that should be overridable but have sane defaults |
| `lib.mkForce` | NixOS stdlib | Override module defaults from host config | Host flake escape hatch for hardcoded fail2ban settings |
| `lib.mkMerge` | NixOS stdlib | Merge multiple `config` attrsets | When a module has conditional sub-configs to combine |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `lib.mkEnableOption` | `lib.mkOption { type = types.bool; default = false; }` | `mkEnableOption` is shorter and self-documenting; prefer it |
| flat `options.nerv.openssh.*` | nested attrset option | Flat is simpler for few options; attrset adds complexity; use flat |

**Installation:** No new packages — all tooling is NixOS stdlib.

---

## Architecture Patterns

### Module File Structure

Every migrated module follows the same skeleton:

```nix
# Source: NixOS module system conventions (nixpkgs/lib/modules.nix)
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.<service>;   # local alias — reduces repetition
in {
  options.nerv.<service> = {
    enable = lib.mkEnableOption "<service description>";
    # additional options with mkOption...
  };

  config = lib.mkIf cfg.enable {
    # all existing module body goes here, with cfg.* substituted for hardcoded values
  };
}
```

### Enable-only module (pipewire, bluetooth, printing)

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.audio;
in {
  options.nerv.audio.enable = lib.mkEnableOption "PipeWire audio stack";

  config = lib.mkIf cfg.enable {
    # entire existing pipewire.nix body here unchanged
  };
}
```

### Multi-option module (openssh)

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.openssh;
in {
  options.nerv.openssh = {
    enable          = lib.mkEnableOption "OpenSSH daemon with endlessh tarpit and fail2ban";
    port            = lib.mkOption {
      type        = lib.types.port;
      default     = 2222;
      description = "Port the SSH daemon listens on. Port 22 is reserved for the endlessh tarpit.";
    };
    tarpitPort      = lib.mkOption {
      type        = lib.types.port;
      default     = 22;
      description = "Port endlessh binds to. Must differ from port.";
    };
    allowUsers      = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      default     = [];
      description = "Restrict SSH access to these users. Empty list allows all users.";
      example     = [ "alice" "bob" ];
    };
    passwordAuth         = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Allow password authentication. Disabled by default (keys only).";
    };
    kbdInteractiveAuth   = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Allow keyboard-interactive authentication.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.tarpitPort != cfg.port;
      message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
    }];

    services.openssh = {
      enable      = true;
      ports       = [ cfg.port ];
      openFirewall = true;
      settings = {
        PasswordAuthentication     = cfg.passwordAuth;
        KbdInteractiveAuthentication = cfg.kbdInteractiveAuth;
        PermitRootLogin            = "no";
      } // lib.optionalAttrs (cfg.allowUsers != []) {
        AllowUsers = cfg.allowUsers;
      };
    };

    services.endlessh = {
      enable      = true;
      port        = cfg.tarpitPort;
      openFirewall = true;
    };

    services.fail2ban = {
      enable    = true;
      maxretry  = 5;
      ignoreIP  = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" ];
      bantime   = "24h";
      bantime-increment = {
        enable       = true;
        maxtime      = "168h";
        overalljails = true;
      };
      jails.sshd.settings = {
        mode     = "aggressive";
        maxretry = 3;
        findtime = 600;
        port     = toString cfg.port;
      };
    };
  };
}
```

### services/default.nix population

```nix
{ imports = [
    ./openssh.nix
    ./pipewire.nix
    ./bluetooth.nix
    ./printing.nix
    ./zsh.nix
  ];
}
```

### host configuration.nix update (nerv.* API)

After migration, `hosts/nixos-base/configuration.nix` must activate the services it needs:

```nix
nerv.openssh = {
  enable    = true;
  allowUsers = [ "demon0" ];
};
nerv.audio.enable    = true;   # or false per host preference
nerv.bluetooth.enable = true;  # or false
nerv.printing.enable  = false;
nerv.secureboot.enable = false; # Phase 4
```

### printing.nix avahi ownership

The current `modules/printing.nix` references `services.avahi.nssmdns4 = true;` but relies on `pipewire.nix` for `services.avahi.enable = true`. After migration, `printing.nix` must also own `avahi.enable = true` directly (per locked decision). Both printing.nix and bluetooth.nix can independently set `avahi.enable = true` — NixOS merges booleans with logical OR.

### Anti-Patterns to Avoid

- **Keeping `services.openssh.settings.AllowUsers` always present:** When `allowUsers = []` (empty, allow all), do NOT set `AllowUsers` at all — an empty list is not the same as "allow all" in sshd. Use `lib.optionalAttrs` to conditionally include it.
- **Keeping hardcoded `AllowUsers = [ "myUser" ]` in the module body:** This is what Phase 2 is fixing. The module must not have any hardcoded user values.
- **Setting `avahi.enable` only in pipewire.nix:** After migration, if audio is disabled, printing would break. Each module that needs avahi must own `avahi.enable = true` within its own `mkIf` block.
- **Forgetting to update `fail2ban.jails.sshd.settings.port`:** The jail monitors `cfg.port`, not the hardcoded "2222". Use `toString cfg.port` since fail2ban expects a string.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Type checking options | Custom validation code | `lib.types.*` in `mkOption` | NixOS evaluates types at build time with helpful errors |
| Port conflict detection | Manual boolean checks | `assertions` list in `config` block | Assertions surface as clear build errors with custom messages |
| Conditional config application | `if cfg.enable then { ... } else {}` | `lib.mkIf cfg.enable { ... }` | `mkIf` integrates with the module system's lazy evaluation |
| Optional list values | `if cfg.allowUsers == [] then {} else { AllowUsers = ...; }` | `lib.optionalAttrs (cfg.allowUsers != []) { ... }` | Idiomatic, concise, no if-then-else in attrset position |

---

## Common Pitfalls

### Pitfall 1: AllowUsers empty list vs absent
**What goes wrong:** Setting `services.openssh.settings.AllowUsers = []` in sshd means "allow no users" — this locks everyone out of SSH.
**Why it happens:** The nerv option default is `[]` meaning "allow all", but sshd interprets an empty `AllowUsers` directive as "allow nobody".
**How to avoid:** Use `lib.optionalAttrs (cfg.allowUsers != []) { AllowUsers = cfg.allowUsers; }` so the directive is only emitted when the list is non-empty.
**Warning signs:** Build succeeds but `ssh` returns "Permission denied" for all users.

### Pitfall 2: fail2ban jail port must be a string
**What goes wrong:** `services.fail2ban.jails.sshd.settings.port = cfg.port` fails evaluation because `cfg.port` is `types.port` (an int) and fail2ban expects a string.
**Why it happens:** The fail2ban NixOS option type for jail settings is `types.str`.
**How to avoid:** Use `port = toString cfg.port;`.
**Warning signs:** `nix flake check` or `nixos-rebuild build` gives type mismatch error on the jails attrset.

### Pitfall 3: zsh interactiveShellInit load order breakage
**What goes wrong:** Moving code blocks around in zsh.nix disrupts the manual source ordering of syntax-highlighting before history-substring-search, causing history widget wrapping to silently fail.
**Why it happens:** The current zsh.nix has comments explaining the required load order: autosuggestions → syntax-highlighting → history-substring-search. This order is non-obvious and easy to break when editing.
**How to avoid:** Keep the entire `interactiveShellInit` block intact. When stripping starship (~lines 122-186) and fonts (~lines 188-198), only remove those blocks; do not reorder the `interactiveShellInit` content.
**Warning signs:** Arrow-key history search stops working in zsh sessions.

### Pitfall 4: avahi not enabled for printing after pipewire migration
**What goes wrong:** If `nerv.audio.enable = false` on a host that uses printing, `services.avahi.enable` is never set to true, so `avahi.nssmdns4 = true` has no effect and network printer discovery fails.
**Why it happens:** The original `printing.nix` relied on `pipewire.nix` always being imported (and always enabling avahi). After migration, each module is independently guarded by `mkIf`.
**How to avoid:** `printing.nix` must set both `services.avahi.enable = true` and `services.avahi.nssmdns4 = true` within its own `mkIf cfg.enable` block.
**Warning signs:** `avahi-browse -a` returns no results even with `nerv.printing.enable = true`.

### Pitfall 5: secureboot.nix accidentally referenced
**What goes wrong:** Adding `./secureboot.nix` to `modules/services/default.nix` would pull lanzaboote into the evaluation prematurely.
**Why it happens:** The file exists in `modules/` and could be accidentally listed.
**How to avoid:** `modules/services/default.nix` imports only: openssh, pipewire, bluetooth, printing, zsh. secureboot stays out of scope until Phase 4.

---

## Code Examples

### Assertion pattern for port conflict detection

```nix
# Source: NixOS module system — assertions list in config block
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

### optionalAttrs for conditional AllowUsers

```nix
# Source: nixpkgs/lib/attrsets.nix
settings = {
  PasswordAuthentication        = cfg.passwordAuth;
  KbdInteractiveAuthentication  = cfg.kbdInteractiveAuth;
  PermitRootLogin               = "no";
} // lib.optionalAttrs (cfg.allowUsers != []) {
  AllowUsers = cfg.allowUsers;
};
```

### mkEnableOption (canonical form)

```nix
# Source: nixpkgs/lib/options.nix
options.nerv.audio.enable = lib.mkEnableOption "PipeWire audio stack";
# Equivalent to:
# lib.mkOption { type = lib.types.bool; default = false; description = "Whether to enable PipeWire audio stack."; }
```

### Correct fail2ban port stringification

```nix
jails.sshd.settings = {
  mode     = "aggressive";
  maxretry = 3;
  findtime = 600;
  port     = toString cfg.port;   # types.port is int; fail2ban setting is string
};
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat module files imported directly | Options modules with `nerv.*` API | Phase 2 (now) | Host flakes configure via options; no module file editing |
| `AllowUsers = [ "myUser" ]` hardcoded | `cfg.allowUsers` consumed from option | Phase 2 | User-replaceable without touching module source |
| `services.avahi.enable` owned by pipewire | Each module owns its own avahi dependency | Phase 2 | Decoupled — printing works without audio enabled |

---

## Open Questions

1. **Whether to add `nerv.openssh` assertion for tarpitPort != port**
   - What we know: Claude's discretion — user left this to research/planning
   - What's unclear: Whether build-time assertions are desired or `lib.mkForce` is sufficient
   - Recommendation: Include the assertion — it is a near-zero cost guard against a silent configuration error that would leave port 22 with two services competing

2. **Nix aliases in zsh.nix are hardcoded to `/etc/nerv#nixos-base`**
   - What we know: Locked decision — no option exposed to configure the flake path
   - What's unclear: Current aliases point to `/etc/nixos#nixos` (old path) — these need updating to `/etc/nerv#nixos-base` as part of Phase 2 migration
   - Recommendation: Update the aliases during zsh.nix migration as a correction, not a new feature

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — no pytest.ini, jest.config.*, vitest.config.*, or test/ directory in repo |
| Config file | None — see Wave 0 |
| Quick run command | `nix flake check` (evaluates module types and assertions) |
| Full suite command | `nixos-rebuild build --flake .#nixos-base` (full system build) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPT-05 | `nerv.openssh.allowUsers = ["demon0"]` sets `AllowUsers` in sshd; empty default omits directive | smoke | `nix flake check` — evaluation validates option type and AllowUsers omission | ❌ Wave 0: verify via nix eval |
| OPT-06 | `nerv.openssh.passwordAuth = false` sets `PasswordAuthentication = false` in sshd | smoke | `nix flake check` | ❌ Wave 0 |
| OPT-07 | `nerv.openssh.port = 2222` sets `services.openssh.ports = [2222]` and fail2ban jail port | smoke | `nix flake check` | ❌ Wave 0 |
| OPT-08 | `nerv.audio.enable = false` (default) produces no PipeWire config; `= true` enables full stack | smoke | `nix flake check` + `nixos-rebuild build --flake .#nixos-base` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `nix flake check`
- **Per wave merge:** `nixos-rebuild build --flake .#nixos-base`
- **Phase gate:** Full `nixos-rebuild build` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] Nix evaluation not formalized as unit tests — this project uses `nix flake check` + `nixos-rebuild build` as the test oracle; no separate test framework is warranted
- [ ] Verify `nix` is available in the dev environment for `nix flake check`: `nix --version`

*(No traditional test files to create — NixOS modules are validated by the Nix evaluator itself. The "test infrastructure" is correct module authoring and build verification.)*

---

## Sources

### Primary (HIGH confidence)
- NixOS module system source: `nixpkgs/lib/modules.nix`, `nixpkgs/lib/options.nix` — `mkOption`, `mkEnableOption`, `mkIf`, `types.*`, `assertions`
- Existing module files read directly from repo: `modules/openssh.nix`, `modules/pipewire.nix`, `modules/bluetooth.nix`, `modules/printing.nix`, `modules/zsh.nix` — exact current code confirmed
- `modules/services/default.nix` — confirmed as `{ imports = []; }` stub
- `hosts/nixos-base/configuration.nix` — confirmed current host config structure
- `flake.nix` — confirmed module wiring and nixosConfigurations entry point
- `.planning/phases/02-services-reorganization/02-CONTEXT.md` — locked decisions confirmed

### Secondary (MEDIUM confidence)
- NixOS Wiki — module system conventions align with nixpkgs source; no contradictions found

### Tertiary (LOW confidence)
- None required — all findings grounded in repo source or NixOS stdlib

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — NixOS stdlib; no external dependencies introduced
- Architecture: HIGH — patterns read directly from existing repo code + NixOS module system conventions
- Pitfalls: HIGH — AllowUsers and fail2ban port pitfalls derived from reading actual sshd/fail2ban NixOS option types; zsh pitfall derived from existing code comments

**Research date:** 2026-03-06
**Valid until:** 2026-06-06 (NixOS stdlib is stable; avahi/fail2ban/endlessh NixOS module APIs change infrequently)
