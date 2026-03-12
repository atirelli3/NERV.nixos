# Phase 15: Starship Prompt Integration - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Append `programs.starship` to the existing `modules/services/zsh.nix` so that any host with `nerv.zsh.enable = true` gets a minimal two-line shell prompt automatically — no separate toggle. The starship config is stored in the Nix store (impermanence-safe). This phase touches only `modules/services/zsh.nix`.

</domain>

<decisions>
## Implementation Decisions

### Activation
- Starship activates automatically when `nerv.zsh.enable = true` — no `nerv.zsh.starship.enable` option
- Use `programs.starship.enable = true` exclusively — never `interactiveShellInit eval`; double init clobbers ZLE hooks
- `programs.starship.interactiveOnly` left at default `true` — moves starship init after `interactiveShellInit` block, preserving history-substring-search ZLE bindings

### Prompt format
- Two-line prompt: line 1 = username, line 2 = prompt character
- Username color: dim cyan for regular users, **red for root** (immediate visual warning)
- Username visibility: always shown (both regular users and root)
- Prompt character: `$` for regular users (white on exit 0, red on non-zero exit); `#` for root
- No other modules — only username and character modules active; all others disabled via `format`

### add_newline
- `add_newline = true` (Starship default) — blank line before each prompt for visual separation between command blocks

### Impermanence safety
- `programs.starship.settings` (Nix attrs) generates config in Nix store; NixOS sets `STARSHIP_CONFIG` automatically to the store path — survives root subvolume rollback
- Do NOT set STARSHIP_CONFIG manually in `interactiveShellInit`

### Claude's Discretion
- Exact `format` string structure (module ordering, newline placement)
- `scan_timeout` / `command_timeout` values (minimal prompt, defaults are fine)
- Option description wording in the module

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `cfg = config.nerv.zsh` alias already established — no new cfg alias needed
- `lib.mkIf cfg.enable { ... }` config block — starship settings appended inside this block

### Established Patterns
- `programs.zsh.interactiveShellInit` block manually sources: syntax-highlighting → history-substring-search → binds `^[[A`/`^[[B` to arrow keys
- `programs.starship.interactiveOnly = true` (default) appends starship init AFTER `interactiveShellInit` — this is the correct ordering that protects the ZLE bindings
- Comment style: `# inline comment for non-obvious lines`, section headers descriptive

### Integration Points
- `programs.starship` is a top-level NixOS option — no new import needed
- `environment.systemPackages` already has `eza fzf`; starship is added via `programs.starship.enable` (not systemPackages)
- No changes to `modules/services/default.nix` (zsh.nix already imported)
- No changes to `flake.nix`

</code_context>

<specifics>
## Specific Ideas

- Root shell: red username + `#` character makes it immediately obvious you are in an elevated context
- The `format` string should reference only `$username` and `$character` modules — everything else excluded so no extra info bleeds in even if nixpkgs adds new default modules in the future

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 15-starship-prompt-integration*
*Context gathered: 2026-03-12*
