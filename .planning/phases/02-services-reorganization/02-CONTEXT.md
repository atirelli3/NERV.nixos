# Phase 2: Services Reorganization - Context

**Gathered:** 2026-03-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate `openssh.nix`, `pipewire.nix`, `bluetooth.nix`, `printing.nix`, and `zsh.nix` into `modules/services/` and wrap each in typed `options.nerv.*` blocks. Service behavior is exclusively API-driven after this phase — no hardcoded values in module bodies. The `modules/services/default.nix` aggregator (currently an empty stub from Phase 1) is populated with the migrated modules.

Requirements: OPT-05, OPT-06, OPT-07, OPT-08

</domain>

<decisions>
## Implementation Decisions

### openssh enable and port
- `nerv.openssh.enable = true` is required to activate SSH — off by default, consistent with audio/bluetooth/printing
- Default port: **2222** (matches current behavior; port 22 is reserved for the endlessh tarpit)
- OPT-07 requirement should be updated: default is 2222, not 22

### openssh companion services (endlessh + fail2ban)
- Endlessh (tarpit) and fail2ban are **always-on** when `nerv.openssh.enable = true` — part of the nerv security posture, no opt-out
- `nerv.openssh.tarpitPort` option (default: 22) — exposed because the tarpit port is conceptually coupled to the SSH port choice
- fail2ban settings (maxretry, bantime, bantime-increment, ignoreIP private subnets, sshd aggressive jail) are **hardcoded opinionated defaults** — not exposed as options; host flakes can override via `lib.mkForce` if needed

### avahi cross-dependency
- `printing.nix` owns `avahi.enable = true` itself — self-contained, no dependency on audio being enabled
- `bluetooth.nix` also sets `avahi.enable = true` (for BT service advertisement via mDNS)
- NixOS merges duplicate `avahi.enable = true` cleanly — having both printing and bluetooth set it is safe
- bluetooth.nix wireplumber codec config is included unconditionally — if PipeWire is not enabled, the settings have no effect; no `mkIf` guard needed

### zsh module scope
- **Remove from zsh.nix:** starship prompt configuration and NerdFont declarations (belong in user's home.nix)
- **Keep in zsh.nix:** zsh enable, autosuggestions, syntax-highlighting (manually sourced for load-order correctness), history-substring-search, all keybindings (arrow history search, Ctrl+Left/Right word nav, Home/End/Delete), fzf integration (completion + key-bindings), all shell aliases (eza navigation, git shortcuts, nix shortcuts), sudo-widget (ESC ESC toggle)
- Nix aliases (nrs, nrb, nrt, nfu, ngc, etc.) are **hardcoded to `/etc/nerv#nixos-base`** — no option to configure

### Claude's Discretion
- Exact NixOS options module structure (mkOption types, descriptions, example values)
- Whether `nerv.openssh` uses a sub-attribute set or flat attribute names
- Whether to add assertion errors (e.g., assert tarpitPort != port) for obvious misconfigurations
- Order of imports in `modules/services/default.nix`

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `modules/openssh.nix`: Full implementation with endlessh + fail2ban — wrap in `mkIf cfg.enable`, parameterize ports and allowUsers/auth options
- `modules/pipewire.nix`: No options needed — it's enable-only (`nerv.audio.enable`); all existing PipeWire config stays as-is inside the `mkIf` block
- `modules/bluetooth.nix`: Enable-only (`nerv.bluetooth.enable`); add `avahi.enable = true`; wireplumber config stays unconditional
- `modules/printing.nix`: Enable-only (`nerv.printing.enable`); move `avahi.enable = true` here from pipewire.nix
- `modules/zsh.nix`: Strip starship block (~65 lines) and fonts block (~8 lines); all other content stays
- `modules/secureboot.nix`: NOT migrated in Phase 2 — it's a Phase 4 concern (boot extraction)

### Established Patterns
- Phase 1 established: `nixosModules` values use `import ./path` — options modules follow the same pattern
- `modules/services/default.nix` stub from Phase 1 is `{ imports = []; }` — Phase 2 populates this list

### Integration Points
- Each new `modules/services/*.nix` file is added to the `imports` list in `modules/services/default.nix`
- `hosts/nixos-base/configuration.nix` sets `nerv.*` options — after Phase 2, SSH/audio/bluetooth/printing/zsh are configured there, not by importing flat module files
- Build verification: `nixos-rebuild build --flake .#nixos-base` must pass after each module migration

</code_context>

<specifics>
## Specific Ideas

- The openssh module should reflect the tarpit-first security posture: SSH on non-standard port, port 22 occupied by endlessh, fail2ban with aggressive settings is the default nerv stance
- zsh.nix retains the fzf + history-substring-search keybinding wiring that requires the specific load order (autosuggestions → syntax-highlighting → history-substring-search) — this is non-obvious and should be preserved with its comments

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-services-reorganization*
*Context gathered: 2026-03-06*
