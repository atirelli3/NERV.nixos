# Stack Research: nerv.nixos v3.0

**Project:** nerv.nixos — zram swap + starship prompt
**Researched:** 2026-03-12
**Confidence:** HIGH (options verified from nixpkgs release-25.11 source)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `zramSwap` NixOS module | Built-in (NixOS 25.11) | In-memory compressed swap via kernel zram module | Already in nixpkgs; no extra flake inputs; BTRFS-safe (no swap file on filesystem) |
| `programs.starship` NixOS module | Built-in (NixOS 25.11), starship 1.24.2 | Cross-shell prompt with declarative TOML config | Handles package, zsh promptInit injection, and STARSHIP_CONFIG env automatically |

### Supporting Libraries

None. Both features are provided by built-in NixOS modules. No new flake inputs required.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `zramctl` | Verify zram device compression ratio at runtime | Run as root post-install to confirm zram is active |
| `swapon --show` | Verify swap devices and priorities | Confirms zram swap is active and higher priority than disk |

## NixOS Option Reference

### zramSwap

All options live at the top-level `zramSwap.*` attribute path (NOT under `services.*`).

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `zramSwap.enable` | bool | `false` | Activates zram kernel module and swap devices |
| `zramSwap.swapDevices` | int | `1` | Number of zram swap devices (1 is recommended) |
| `zramSwap.memoryPercent` | positive int | `50` | Max zram size as % of total RAM |
| `zramSwap.memoryMax` | int or null | `null` | Absolute byte ceiling; if set, min(memoryPercent, memoryMax) wins |
| `zramSwap.priority` | int | `5` | Swap priority; higher = filled before disk swap |
| `zramSwap.algorithm` | enum or str | `"zstd"` | Compression: `"zstd"` (best default), `"lz4"` (fastest), `"lzo"` (legacy) |
| `zramSwap.writebackDevice` | path or null | `null` | Block device for incompressible page writeback |

**Implementation note:** `zramSwap` delegates to `services.zram-generator` under the hood. The nerv option `nerv.swap.zram.size` (in MB) as specified in PROJECT.md does not map directly to a single option. Use `zramSwap.memoryMax` (bytes) for an absolute cap, or `zramSwap.memoryPercent` for a RAM-relative default. The nerv wrapper should translate MB → bytes when `memoryMax` is used, or default to `memoryPercent = 50` when no explicit size is set.

**Correct nerv mapping:**
- `nerv.swap.zram.enable = true` → `zramSwap.enable = true`
- `nerv.swap.zram.size` (int, MB) → `zramSwap.memoryMax = nerv.swap.zram.size * 1024 * 1024` (when size != 0), else fall back to `zramSwap.memoryPercent = 50` default

### programs.starship

All options live under `programs.starship.*`.

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `programs.starship.enable` | bool | `false` | Master switch; injects init into all supported shells |
| `programs.starship.package` | package | `pkgs.starship` | Override starship binary (leave as default) |
| `programs.starship.interactiveOnly` | bool | `true` | Init injected into `programs.zsh.promptInit`; false → `shellInit` |
| `programs.starship.settings` | TOML attrs | `{}` | Declarative starship.toml; see starship.rs/config |
| `programs.starship.presets` | list of str | `[]` | Preset files merged before settings (e.g. `"nerd-font-symbols"`) |

**How zsh integration works (verified from source):**

When `programs.starship.enable = true`, the module sets `programs.zsh.promptInit` to:

```bash
if [[ $TERM != "dumb" ]]; then
  if [[ ! -f "$HOME/.config/starship.toml" ]]; then
    export STARSHIP_CONFIG=<nix-store-path/starship.toml>
  fi
  eval "$(starship init zsh)"
fi
```

This is appended to the system-generated `/etc/zshrc` by the `programs.zsh` NixOS module via its `promptInit` hook. It does **not** conflict with `interactiveShellInit` used in the existing `zsh.nix` — those are separate injection points in `/etc/zshrc`.

**Load order in /etc/zshrc (NixOS-generated):**
1. `shellInit` (before completion init)
2. `interactiveShellInit` (after compinit — where our keybindings/fzf live)
3. `promptInit` (after interactiveShellInit — where starship lands)

This ordering is correct: starship init runs last, after all zsh plugins are loaded.

**No `environment.systemPackages` entry needed.** The module references `cfg.package` (pkgs.starship) directly in the init script, which pulls it into the closure. Adding starship to `environment.systemPackages` would be redundant.

**User config override:** If a user has `~/.config/starship.toml`, the module skips setting `STARSHIP_CONFIG` — their local config takes precedence. The `programs.starship.settings` TOML is only active when no `~/.config/starship.toml` exists.

## Installation

```nix
# No new flake inputs needed.

# modules/system/swap.nix (new file)
zramSwap = {
  enable = true;
  memoryPercent = 50;    # or memoryMax = N * 1024 * 1024 for explicit MB cap
  algorithm = "zstd";   # default; leave unless benchmarking
  priority = 5;         # default; higher than disk swap (typically -1 or 0)
};

# modules/services/zsh.nix (add to existing config block)
programs.starship = {
  enable = true;
  settings = {
    # minimal config; see FEATURES.md for exact prompt format
  };
};
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `zramSwap` NixOS module | Manual `services.zram-generator.settings` | Never for nerv — the higher-level module provides cleaner API and nerv-compatible options |
| `programs.starship` NixOS module | `environment.systemPackages = [pkgs.starship]` + manual eval in interactiveShellInit | Only if needing per-user config isolation not achievable via settings; the module approach is cleaner |
| `programs.starship.settings` (declarative TOML) | `home.file.".config/starship.toml"` (Home Manager) | Use Home Manager approach only if users need per-user prompt customization; nerv ships a system-wide default |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `swapDevices` (the fileSystems swap option) | Creates a swap file on BTRFS — unsupported without `nodatacow` and btrfs-specific workarounds | `zramSwap.enable = true` — pure in-memory, no filesystem involvement |
| `zramSwap.swapDevices > 1` | Multiple zram devices add complexity with no benefit for desktop use | Leave at default of 1 |
| `zramSwap.writebackDevice` | Requires a dedicated block partition; adds disk wear | Only relevant for servers with NVMe writeback tier; omit for desktop |
| Adding `pkgs.starship` to `environment.systemPackages` | Redundant when `programs.starship.enable = true` — the module already pulls it into the closure | Use only `programs.starship.enable = true` |
| `programs.starship.interactiveOnly = false` | Injects starship into `shellInit` (non-interactive shells) which wastes startup time | Leave at default `true` — prompt only needed in interactive sessions |
| Manually adding `eval "$(starship init zsh)"` to `interactiveShellInit` | Duplicates what `programs.starship` already injects via `promptInit`; runs starship init twice | Set `programs.starship.enable = true` and let the module handle it |

## Stack Patterns by Variant

**For nerv.swap.zram.enable (new module at modules/system/swap.nix):**
- Use `zramSwap.enable = true` + `zramSwap.memoryPercent = 50` as the default path
- When `nerv.swap.zram.size` is set (non-zero), convert to bytes and use `zramSwap.memoryMax`
- Keep `zramSwap.algorithm = "zstd"` — requires kernel >= 4.19 (zen kernel in nerv exceeds this)

**For nerv.zsh starship integration (modify modules/services/zsh.nix):**
- Add `programs.starship.enable = lib.mkIf cfg.enable true` — starship follows zsh enable
- Add `programs.starship.settings = { ... }` with the minimal prompt config
- Do NOT change `interactiveShellInit` — starship goes into `promptInit` automatically

## Version Compatibility

| Package | NixOS Version | Notes |
|---------|---------------|-------|
| `zramSwap` module | NixOS 25.11 (verified) | `services.zram-generator` backend; `numDevices` option was removed (use `swapDevices`) |
| `starship` 1.24.2 | NixOS 25.11 / nixpkgs (verified 2026-02-23) | `programs.starship` module confirmed present in release-25.11 branch |
| `zstd` compression | Linux kernel >= 4.19 | zen kernel in nerv is well above this threshold |

## Sources

- `https://raw.githubusercontent.com/NixOS/nixpkgs/release-25.11/nixos/modules/config/zram.nix` — verified option names, types, defaults, and `services.zram-generator` delegation
- `https://raw.githubusercontent.com/NixOS/nixpkgs/release-25.11/nixos/modules/programs/starship.nix` — verified option names, `initOption` logic, exact zsh `promptInit` injection code
- `https://mynixos.com/nixpkgs/package/starship` — starship 1.24.2 version confirmed
- `https://www.nixhub.io/packages/starship` — 1.24.2 last updated 2026-02-23
- modules/services/zsh.nix (existing) — confirmed `interactiveShellInit` usage; no conflict with `promptInit`

---
*Stack research for: nerv.nixos v3.0 — zram swap + starship prompt*
*Researched: 2026-03-12*
