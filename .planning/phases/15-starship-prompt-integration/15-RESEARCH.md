# Phase 15: Starship Prompt Integration - Research

**Researched:** 2026-03-12
**Domain:** NixOS programs.starship module, Starship TOML configuration
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Activation**
- Starship activates automatically when `nerv.zsh.enable = true` — no `nerv.zsh.starship.enable` option
- Use `programs.starship.enable = true` exclusively — never `interactiveShellInit eval`; double init clobbers ZLE hooks
- `programs.starship.interactiveOnly` left at default `true` — moves starship init after `interactiveShellInit` block, preserving history-substring-search ZLE bindings

**Prompt format**
- Two-line prompt: line 1 = username, line 2 = prompt character
- Username color: dim cyan for regular users, red for root (immediate visual warning)
- Username visibility: always shown (both regular users and root)
- Prompt character: `$` for regular users (white on exit 0, red on non-zero exit); `#` for root
- No other modules — only username and character modules active; all others disabled via `format`

**add_newline**
- `add_newline = true` (Starship default) — blank line before each prompt for visual separation between command blocks

**Impermanence safety**
- `programs.starship.settings` (Nix attrs) generates config in Nix store; NixOS sets `STARSHIP_CONFIG` automatically to the store path — survives root subvolume rollback
- Do NOT set STARSHIP_CONFIG manually in `interactiveShellInit`

### Claude's Discretion
- Exact `format` string structure (module ordering, newline placement)
- `scan_timeout` / `command_timeout` values (minimal prompt, defaults are fine)
- Option description wording in the module

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PRMT-01 | Starship prompt activates automatically when `nerv.zsh.enable = true` — no separate toggle | `programs.starship.enable = true` placed inside the existing `lib.mkIf cfg.enable` block; no new option needed |
| PRMT-02 | Prompt renders username on line 1 (dim cyan) and `$` on line 2 (white; red on non-zero exit code) with no other modules | `format` string with only `$username\n$character`; `[username]` with `style_user = "cyan dimmed"`, `show_always = true`; `[character]` with `success_symbol = '[\$](white)'`, `error_symbol = '[\$](bold red)'` |
</phase_requirements>

---

## Summary

This phase appends `programs.starship` configuration inside the existing `lib.mkIf cfg.enable` block in `modules/services/zsh.nix`. No new file, no new NixOS option, no new import. The NixOS `programs.starship` module (built-in to nixpkgs since before release-24.11, confirmed present in release-25.11) handles all shell integration: it serializes the Nix `settings` attribute set to TOML in the Nix store, sets `STARSHIP_CONFIG` to that store path automatically, and appends the `starship init zsh` call via `promptInit` (when `interactiveOnly = true`, the default).

The primary technical risk is ZLE binding order. The existing `interactiveShellInit` block manually sources `zsh-syntax-highlighting` and `zsh-history-substring-search` and binds `^[[A`/`^[[B`. Because `programs.starship.interactiveOnly` defaults to `true`, the NixOS module places the starship init call in `promptInit`, which runs after `interactiveShellInit`. This is the correct order: plugins bind their ZLE widgets first, starship initializes second, and does not disturb existing bindings.

The prompt design uses only two Starship modules: `username` and `character`. All other modules are excluded by the top-level `format` string, which lists only `$username\n$character`. This ensures no future nixpkgs default-module additions bleed into the prompt.

**Primary recommendation:** Append `programs.starship = { enable = true; settings = { ... }; };` inside the existing `lib.mkIf cfg.enable` block — nothing else changes.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `programs.starship` (NixOS module) | Built-in, nixpkgs release-25.11 | Starship shell prompt integration | Native NixOS option; no flake input needed; handles TOML generation, STARSHIP_CONFIG, and shell init |
| `starship` (package) | Pulled in automatically by the module | The starship binary | Module manages the package; no explicit `environment.systemPackages` entry needed |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pkgs.formats.toml` | nixpkgs built-in | Serializes Nix attrs to Nix-store TOML file | Used internally by the NixOS module — not called directly |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `programs.starship.enable = true` | `programs.zsh.interactiveShellInit = "eval \"$(starship init zsh)\""` | Manual eval causes double-init if starship module is also active; ZLE hooks run twice, clobbering history-substring-search bindings. Locked decision: module-only. |

**Installation:** No installation needed. `programs.starship` is a built-in NixOS module in nixpkgs release-25.11. The package is added automatically when `enable = true`.

---

## Architecture Patterns

### File Touch Surface

This phase touches exactly one file:

```
modules/services/zsh.nix   # append programs.starship block inside lib.mkIf cfg.enable
```

No other files change.

### Pattern 1: Append inside Existing Guard

**What:** New `programs.starship` stanza is placed inside the existing `config = lib.mkIf cfg.enable { ... }` block — alongside the existing `programs.zsh`, `system.activationScripts.zshDefaultRc`, and `environment.systemPackages` attributes.

**When to use:** Whenever adding a feature that is gated on the same option. Avoids a second `lib.mkIf` and keeps the guard logic in one place.

**Example (Nix structure — not verbatim output):**

```nix
config = lib.mkIf cfg.enable {
  # ... existing programs.zsh, activationScripts, systemPackages ...

  programs.starship = {
    enable = true;
    # interactiveOnly defaults to true — leave unset
    settings = {
      add_newline = true;
      format      = "$username\n$character";

      username = {
        style_user  = "cyan dimmed";
        style_root  = "red bold";
        format      = "[$user]($style)\n";
        show_always = true;
        disabled    = false;
      };

      character = {
        success_symbol = ''[\$](white)'';
        error_symbol   = ''[\$](bold red)'';
        disabled       = false;
      };
    };
  };
};
```

**Note on `format` string:** The top-level `format` controls which modules are shown. Setting it to `"$username\n$character"` excludes every other module unconditionally. The username module's own `format` option controls the per-module render — set to `"[$user]($style)\n"` to place only the user name (no " in " suffix) on line 1.

### Pattern 2: Nix String Escaping for `$` in Format Strings

**What:** Starship format strings use `$` as a module variable sigil. To display a literal `$` character, escape it as `\$`. In Nix, the double-quoted string `"[\$](white)"` passes `\$` to the TOML file correctly. Using Nix double-bracket strings (`''...''`) avoids the need to double-escape.

**Example:**

```nix
# In Nix double-bracket strings, \$ is literal — no extra escaping:
success_symbol = ''[\$](white)'';
error_symbol   = ''[\$](bold red)'';
```

The generated TOML will contain:
```toml
success_symbol = '[\$](white)'
```

Which Starship interprets as: render `$` in white style.

### Pattern 3: STARSHIP_CONFIG Impermanence Safety

**What:** The NixOS `programs.starship` module conditionally exports `STARSHIP_CONFIG` pointing to the Nix-store TOML file — but only if `$HOME/.config/starship.toml` does NOT exist.

**Impermanence interaction:** On an impermanent system (root subvolume rolled back on boot), `$HOME/.config/starship.toml` is never present after rollback (home is ephemeral or managed by impermanence module). Therefore `STARSHIP_CONFIG` is always set to the Nix store path — the config survives rollback unconditionally.

**Do NOT** set `STARSHIP_CONFIG` manually in `interactiveShellInit`. The module handles it. Manual setting would override the conditional logic and could conflict with per-user overrides.

### Anti-Patterns to Avoid

- **Double init via eval:** Adding `eval "$(starship init zsh)"` to `interactiveShellInit` in addition to `programs.starship.enable = true` causes starship to initialize twice. The second init re-registers the `precmd` hook and wraps ZLE widgets again, clobbering `history-substring-search` bindings.
- **`interactiveOnly = false`:** Setting this moves starship init to `shellInit`, which runs before `interactiveShellInit`. At that point `zsh-syntax-highlighting` and `zsh-history-substring-search` have not been sourced yet. Starship would initialize, then the plugin chain would run and overwrite widget bindings correctly — but the ordering is fragile. Leave at default `true`.
- **Manually setting `STARSHIP_CONFIG`:** The module sets it conditionally (respecting `~/.config/starship.toml`). Overriding it in shell init breaks per-user customization.
- **Using `format = "$all"`:** This default pulls in every enabled module. In the future, nixpkgs may add new default modules to starship that bleed into the prompt. Explicitly listing only `$username\n$character` is future-proof.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Starship TOML config in Nix store | Custom `writeText` + `environment.variables.STARSHIP_CONFIG` | `programs.starship.settings` | Module handles TOML serialization, store path, STARSHIP_CONFIG export, and conditional override logic |
| Shell init for starship | `interactiveShellInit = ''eval "$(starship init zsh)"''` | `programs.starship.enable = true` | Module uses `promptInit`, guarantees correct ordering, avoids double-init |
| Root user detection in prompt | Custom POSIX logic in `interactiveShellInit` | Starship `username.style_root` + `username.format` | Starship natively differentiates root vs user via separate style options |

**Key insight:** The NixOS `programs.starship` module is a thin but complete wrapper. It handles everything: package, TOML generation, store path, env var, and shell hook ordering. Using it as-is avoids all edge cases around double-init, ZLE hook ordering, and impermanence.

---

## Common Pitfalls

### Pitfall 1: ZLE Binding Destruction via Double Init

**What goes wrong:** `eval "$(starship init zsh)"` in `interactiveShellInit` combined with `programs.starship.enable = true` runs starship initialization twice. The second run re-wraps the `zle-line-init` and `precmd` hooks, overwriting the `bindkey` calls for `history-substring-search-up/down`.

**Why it happens:** Starship's init script registers `zle` widget wrappers. Running it twice means the second run sees the already-wrapped widgets and wraps them again, corrupting the chain.

**How to avoid:** Use `programs.starship.enable = true` only. Never add `eval "$(starship init zsh)"` to `interactiveShellInit`.

**Warning signs:** Arrow-up / arrow-down no longer search by prefix after enabling starship; they fall back to basic history navigation.

### Pitfall 2: `interactiveOnly = false` Breaks Plugin Load Order

**What goes wrong:** Setting `programs.starship.interactiveOnly = false` moves starship init to `shellInit`, which runs before `interactiveShellInit`. This means starship initializes before `zsh-syntax-highlighting` and `zsh-history-substring-search` are sourced, leaving the ZLE binding sequence in an undefined state.

**Why it happens:** NixOS zsh module applies shell init in order: `shellInit` → `interactiveShellInit` → `promptInit`. Only `promptInit` guarantees "after all interactive plugins."

**How to avoid:** Leave `interactiveOnly` at its default `true`. Do not set it in the config.

**Warning signs:** Same as Pitfall 1 — arrow-key history search fails.

### Pitfall 3: `~/.config/starship.toml` Suppresses STARSHIP_CONFIG

**What goes wrong:** If a user manually creates `~/.config/starship.toml` (or if impermanence persists `~/.config/` contents), the NixOS module's conditional check skips setting `STARSHIP_CONFIG`. Starship then uses the user's file instead of the Nix-store config, deviating from the system-defined prompt.

**Why it happens:** The NixOS module explicitly checks `[[ ! -f "$HOME/.config/starship.toml" ]]` before exporting `STARSHIP_CONFIG`. This is intentional — it allows per-user override. On a pure impermanent setup (home wiped on boot), this is a non-issue.

**How to avoid:** For the nerv.nixos use case, impermanent home means this file never persists across rollback. No action needed. Document that users who persist `~/.config/` can create `~/.config/starship.toml` to override the system prompt.

**Warning signs:** `echo $STARSHIP_CONFIG` is empty or unset in a login shell; prompt differs from the expected two-line format.

### Pitfall 4: Literal `$` Not Escaped in Format Strings

**What goes wrong:** Writing `success_symbol = "[$](white)"` without escaping — Starship interprets `$` as the start of a variable reference and renders nothing (empty variable name error, or silently empty symbol).

**Why it happens:** `$` is a special sigil in Starship format strings. It must be written as `\$` to appear literally.

**How to avoid:** Use `''[\$](white)''` (Nix double-bracket string) for `success_symbol` and `error_symbol`. The double-bracket form passes `\$` through to TOML without Nix consuming the backslash.

**Warning signs:** Prompt character is blank; no `$` appears on line 2.

### Pitfall 5: Username Module `format` Has Trailing " in " by Default

**What goes wrong:** The default `format` for the username module is `"[$user]($style) in "` — if only `$username` is referenced in the top-level format without overriding the module's own `format`, the prompt reads `demon in ` on line 1 instead of just `demon`.

**Why it happens:** Starship modules have their own `format` option that controls per-module rendering. The username module's default appends " in " as a separator for use with the directory module.

**How to avoid:** Override `username.format = "[$user]($style)"` (no trailing " in "). This gives a clean single-word username on line 1.

---

## Code Examples

### Complete programs.starship Block

```nix
# Source: NixOS programs.starship module (release-25.11) + starship.rs/config
programs.starship = {
  enable = true;
  # interactiveOnly defaults to true — do not set; ensures starship init runs
  # via promptInit (after interactiveShellInit), preserving ZLE bindings from
  # zsh-history-substring-search.
  settings = {
    add_newline = true;

    # Only username and character modules are active; everything else is
    # excluded by naming them explicitly here. The \n between them puts the
    # prompt character on a separate line.
    format = "$username\n$character";

    username = {
      style_user  = "cyan dimmed";
      style_root  = "red bold";
      format      = "[$user]($style)"; # no trailing " in " — clean single word
      show_always = true;              # show even outside SSH sessions
      disabled    = false;
    };

    character = {
      # \$ is the escaped literal dollar sign in starship format strings.
      # Nix double-bracket strings pass the backslash through to TOML as-is.
      success_symbol = ''[\$](white)'';
      error_symbol   = ''[\$](bold red)'';
      disabled       = false;
    };
  };
};
```

### Verifying STARSHIP_CONFIG After Rebuild

```bash
# In a new login shell after nixos-rebuild switch:
echo $STARSHIP_CONFIG
# Expected: /nix/store/<hash>-starship.toml

# Confirm the file exists and is readable:
cat "$STARSHIP_CONFIG"
```

### Verifying Arrow-Key History Search Works

```bash
# Type a partial command, press Up arrow — should search history by prefix:
ls  # then press Up — should cycle through history entries starting with "ls"
# If Up arrow shows raw escape code '^[[A', ZLE binding is broken.
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `eval "$(starship init zsh)"` in `.zshrc` | `programs.starship.enable = true` in NixOS | nixpkgs ~22.05 | Declarative; correct init ordering; no double-init |
| Manual `STARSHIP_CONFIG` env var | Automatic via NixOS module's conditional export | Same | Respects per-user overrides; impermanence-safe |

**Deprecated/outdated:**
- Direct eval in `interactiveShellInit`: works but breaks ZLE ordering when combined with the NixOS module. Never use both together.

---

## Open Questions

1. **Root user prompt character**
   - What we know: The `character` module uses `success_symbol` for the prompt character. Starship does not have a built-in "root uses `#`" distinction in the character module.
   - What's unclear: The CONTEXT.md specifies `#` for root. This may require either (a) a custom command module checking `$USER`, or (b) relying on the username module's red `#` display in combination with the standard `$` character. Given the locked decision is "username and character modules only, no other modules," option (a) is out of scope. The red `style_root` on the username module (line 1) provides sufficient root warning. The `$` vs `#` distinction on line 2 is NOT achievable with username+character modules alone.
   - Recommendation: Use `$` for all users on line 2 (via `character` module). The red username on line 1 (`style_root = "red bold"`) is the visual warning signal. If `#` for root is required, it needs a custom command module — discuss with user before planning or treat as Claude's discretion (use `$` for all).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — NixOS module; validation is runtime observation |
| Config file | N/A |
| Quick run command | `nixos-rebuild dry-build --flake /etc/nixos#host` |
| Full suite command | `nixos-rebuild switch --flake /etc/nixos#host && exec zsh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRMT-01 | Starship activates with `nerv.zsh.enable = true`, no extra option | smoke | `nixos-rebuild dry-build --flake /etc/nixos#host 2>&1 \| grep -v error` | ❌ Wave 0 |
| PRMT-02 | `echo $STARSHIP_CONFIG` resolves to Nix store path; `cat "$STARSHIP_CONFIG"` shows only username+character | manual | `echo $STARSHIP_CONFIG && cat "$STARSHIP_CONFIG"` | ❌ Wave 0 |

**Note:** NixOS module configuration does not support unit tests in the traditional sense. Validation is: (1) `dry-build` passes evaluation, (2) runtime smoke check of `$STARSHIP_CONFIG` and visual inspection of the prompt.

### Sampling Rate

- **Per task commit:** `nixos-rebuild dry-build --flake /etc/nixos#host`
- **Per wave merge:** `nixos-rebuild switch --flake /etc/nixos#host` + open new shell + visual verify
- **Phase gate:** Dry-build green + visual prompt verification before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No test infrastructure to create — validation is manual runtime observation
- [ ] Dry-build check: `nixos-rebuild dry-build --flake /etc/nixos#host` — confirm no evaluation errors after zsh.nix edit

---

## Sources

### Primary (HIGH confidence)

- NixOS nixpkgs `release-25.11` — `nixos/modules/programs/starship.nix` — options, `interactiveOnly` behavior, STARSHIP_CONFIG conditional export, TOML serialization
- [Starship configuration docs](https://starship.rs/config/) — `username` module options (`style_user`, `style_root`, `format`, `show_always`), `character` module options (`success_symbol`, `error_symbol`), `format` global string, `add_newline`
- Existing `modules/services/zsh.nix` — load order of `interactiveShellInit` plugins (syntax-highlighting → history-substring-search → bindings)

### Secondary (MEDIUM confidence)

- [NixOS Wiki: Starship](https://wiki.nixos.org/wiki/Starship) — `programs.starship.settings` Nix attr example confirming `\n` in format strings works
- [mynixos.com — programs.starship.interactiveOnly](https://mynixos.com/nixpkgs/option/programs.starship.interactiveOnly) — confirms default `true`, documents promptInit vs shellInit distinction
- [Starship Discussion #3182 — escaping `$`](https://github.com/starship/starship/discussions/3182) — confirms `\$` is the correct escape for literal dollar sign in format strings

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — programs.starship is built-in to nixpkgs release-25.11, confirmed in source
- Architecture: HIGH — interactiveOnly behavior verified in module source; format string behavior verified in official docs
- Pitfalls: HIGH — ZLE ordering from existing zsh.nix code is directly observable; $-escaping from official Starship discussion; STARSHIP_CONFIG conditional from module source

**Research date:** 2026-03-12
**Valid until:** 2026-06-12 (stable — Starship config format rarely changes; NixOS module interface stable)
