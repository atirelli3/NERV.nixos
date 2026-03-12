# Features Research: nerv.nixos v3.0

**Project:** nerv.nixos — Polish & UX (zram swap + starship prompt)
**Focus:** zram compressed swap for BTRFS host profile; starship prompt integrated into nerv.zsh
**Confidence:** HIGH (zram options from nixpkgs source + MyNixOS; starship from starship.rs/config + NixOS module source)

---

## v3.0 Scope

Two features being added to the existing library:

1. **`nerv.swap.zram`** — In-memory compressed swap using the NixOS `zramSwap` module. BTRFS-safe (no swap partition needed). Opt-in via `nerv.swap.zram.enable`.
2. **Starship prompt in `nerv.zsh`** — Minimal two-line prompt: dim cyan username on line 1, white `$` on line 2. No powerline fonts required. Injected via `programs.starship` NixOS system module.

---

## Feature Landscape

### Table Stakes (Users Expect These)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `nerv.swap.zram.enable` option (default: false) | Users expect an opt-in toggle, not always-on | LOW | zramSwap.enable already a single boolean in nixpkgs |
| `nerv.swap.zram.memoryPercent` option (default: 50) | Configurable size; 50 is the nixpkgs default and reasonable for most desktops | LOW | 50% = ~15-25% of RAM actually consumed due to 2:1-3:1 compression ratio |
| Algorithm fixed to `zstd` | zstd is the nixpkgs default since ~2023 and the community-recommended choice for desktop; good compression, fast enough on modern CPUs | LOW | No user-facing algorithm option needed — zstd is strictly better than lzo/lz4 for desktops unless swap is constant/continuous |
| `zramSwap.priority` set to 100 | Without an elevated priority, kernel may prefer disk swap over zram | LOW | nixpkgs default is 5; 100 is the community consensus for "prefer zram" |
| Starship prompt enabled when `nerv.zsh.enable = true` | Users enabling zsh expect a usable prompt; the current PS1 is the bare default | LOW | Wired via `programs.starship.enable = true` + `enableZshIntegration = true` in the same zsh.nix module |
| Two-line format: username line 1, `$` line 2 | Minimal, readable; one line per context, one line for input | LOW | `format = "$username\n$character"` — no other modules on the prompt |
| Dim cyan username, white `$` | Subtle color; readable on dark and light terminals without bright/distracting ANSI | LOW | `[username] style_user = "dim cyan"` + `[character] success_symbol = "[$](white)"` |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| BTRFS-safe in-memory swap | BTRFS profile has no swap partition; zram fills the gap without touching disk layout | LOW | No disko changes needed — purely a kernel module + udev unit |
| Prompt that respects impermanence | `.zshrc` is empty by design (written by activation script); starship config lives in `/etc/starship.toml` (system-level, survives rollback) | LOW | `programs.starship` writes `/etc/starship.toml` automatically — no user-facing dotfile required |
| Error feedback on `$` symbol | `success_symbol` vs `error_symbol` both set to `$` but different colors (white vs red) makes exit code visible without verbosity | LOW | `error_symbol = "[$](red)"` — minimal but informative |
| No powerline fonts required | Prompt uses only ASCII `$` — works on any terminal, including SSH sessions and VMs | LOW | Deliberately avoid nerd-font icons in system defaults |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| User-facing `nerv.swap.zram.algorithm` option | Looks like a nice tuning knob | lz4 vs zstd decision is a micro-optimization most operators won't understand; zstd is correct for desktops, lz4 only wins if swap is constant | Hard-code zstd; document override via `zramSwap.algorithm = lib.mkForce "lz4"` if needed |
| Full starship module with git, languages, cloud | Rich context is the default starship experience | Slow on large repos; distracts from minimal aesthetic; all that info belongs in user's dotfiles, not system defaults | Two-line, username + `$` only; user extends via `~/.config/starship.toml` (or HM) |
| `nerv.swap.zram.swapDevices` option | Multiple zram devices for multi-CPU systems | nixpkgs recommendation is 1; multiple devices add complexity for negligible benefit on typical desktop hardware | Fix at 1; document `zramSwap.swapDevices = lib.mkForce 2` for power users |
| `zramSwap.writebackDevice` support | "Writeback idle pages to disk" sounds efficient | Adds persistent storage dependency; increases disko complexity; rarely beneficial on systems with BTRFS + sufficient RAM | Out of scope; document the nixpkgs option for operators who need it |
| Starship in `home/` skeleton | Some users want per-user config | System-level `programs.starship` already writes `/etc/starship.toml` for all users; per-user overrides work via `~/.config/starship.toml` without any nerv module | Keep in `modules/services/zsh.nix` (system scope) — home skeleton is user responsibility |

---

## Feature Dependencies

```
nerv.swap.zram.enable = true
    └──writes──> zramSwap.enable = true
    └──writes──> zramSwap.algorithm = "zstd"
    └──writes──> zramSwap.memoryPercent = cfg.memoryPercent  (default 50)
    └──writes──> zramSwap.priority = 100

nerv.zsh.enable = true  (already exists)
    └──enhances──> Starship prompt injection
    └──Starship wired via programs.starship.enable = true
                          programs.starship.enableZshIntegration = true
                          programs.starship.settings = { ... }
    └──No conflict with interactiveShellInit — programs.starship uses its own
       zsh hook (appended to /etc/zshrc by the NixOS module automatically)
```

### Dependency Notes

- **zram has no dependency on disko layout**: `zramSwap` is a pure kernel module; it works regardless of BTRFS or LVM layout. `nerv.swap.zram.enable` does not require `nerv.disko.layout`.
- **Starship requires `programs.zsh.enable = true`**: `programs.starship.enableZshIntegration` appends `starship init zsh` to `/etc/zshrc`. `programs.zsh.enable` must be true for `/etc/zshrc` to exist. Since `nerv.zsh.enable` already sets `programs.zsh.enable = true`, the dependency is satisfied automatically.
- **Starship does not conflict with `interactiveShellInit`**: The NixOS `programs.starship` module manages its own zsh hook separately from `programs.zsh.interactiveShellInit`. Both coexist.
- **Starship config survives impermanence rollback**: `/etc/starship.toml` is a Nix-managed file written to the store, not to `/etc/nixos`. It is rebuilt on every `nixos-rebuild switch` regardless of root rollback.

---

## zram Option Details

### NixOS `zramSwap` Module Options (Verified)

| Option | Type | nixpkgs Default | nerv Default | Notes |
|--------|------|-----------------|--------------|-------|
| `zramSwap.enable` | bool | false | false | Set true when `nerv.swap.zram.enable` |
| `zramSwap.algorithm` | enum | "zstd" | "zstd" (hard-coded) | Valid values: "842", "lzo", "lzo-rle", "lz4", "lz4hc", "zstd" |
| `zramSwap.memoryPercent` | int | 50 | user-configurable (default 50) | 50% = ~15-25% RAM consumed due to 2:1-3:1 compression |
| `zramSwap.priority` | int | 5 | 100 | 100 = prefer zram over any disk swap |
| `zramSwap.swapDevices` | int | 1 | 1 (hard-coded) | Recommendation: always 1 |
| `zramSwap.memoryMax` | int or null | null | unset | Known bug (#435031): values above 50% of RAM are silently capped |
| `zramSwap.writebackDevice` | string | "" | unset | Out of scope |

### Algorithm Rationale (MEDIUM confidence — WebSearch + multiple sources agree)

- **zstd**: Best compression ratio (2:1-3:1 typical), fast on modern CPUs, nixpkgs default since ~NixOS 23.05. Correct choice for desktops with infrequent swap usage (e.g., stale browser tabs).
- **lz4**: Faster compression/decompression, lower compression ratio. Worth considering only if swap is constant (high-throughput workloads). Not recommended for typical desktop.
- **lzo / lzo-rle**: Older algorithms. Slower than lz4, lower ratio than zstd. No modern justification.
- **Recommendation**: Hard-code `zstd`. Expose no algorithm option. Document `lib.mkForce` escape hatch.

### memoryPercent Guidance

- nixpkgs default of 50 is **not** "half your RAM gets used." Due to 3:1 compression, ~50% memoryPercent results in ~15-25% of physical RAM actually allocated to zram at peak.
- For 8 GB RAM: zram device is 4 GB in size, but physically consumes ~1.3-2 GB.
- For 16 GB RAM: zram device is 8 GB in size, but physically consumes ~2.6-4 GB.
- 50 is the right default. Users with 4 GB RAM may want to lower it; users who need more swap can increase it.

---

## Starship Config Format

### Minimal Two-Line Format (HIGH confidence — starship.rs/config verified)

```nix
programs.starship = {
  enable = true;
  enableZshIntegration = true;
  settings = {
    add_newline = false;
    format = "$username\n$character";

    username = {
      style_user   = "dim cyan";
      style_root   = "bold red";
      format       = "[$user]($style) ";
      show_always  = true;
    };

    character = {
      success_symbol = "[$](white)";
      error_symbol   = "[$](red)";
    };
  };
};
```

### Format String Explanation

- `$username` — renders `[<user>](dim cyan)` for regular users, `[root](bold red)` for root
- `\n` — literal newline in the format string creates the two-line split
- `$character` — renders `$` in white (success) or red (error)
- `show_always = true` — username renders even on local terminal (default hides it if SSH is not active)
- `add_newline = false` — suppress the extra blank line above the prompt that starship adds by default; keeps display compact

### Why Not More Modules

Standard starship config includes `$directory`, `$git_branch`, `$git_status`, language runtimes, etc. These are excluded from the system default because:

1. They increase prompt latency on large repos.
2. They belong in user dotfiles, not system-wide config.
3. The nerv library is a base; operators are expected to extend from here.

Users can add any starship modules by placing `~/.config/starship.toml` or configuring via Home Manager — `programs.starship` at system level sets the floor, not the ceiling.

---

## MVP Definition

### v3.0 — Launch With

- [ ] `nerv.swap.zram.enable` (default: false) — activates zramSwap with zstd, priority 100, swapDevices 1
- [ ] `nerv.swap.zram.memoryPercent` (default: 50) — passthrough to `zramSwap.memoryPercent`
- [ ] Starship prompt in `modules/services/zsh.nix` — enabled when `nerv.zsh.enable = true`
- [ ] Two-line format: dim cyan username line 1, white `$` line 2 (`$` red on error)
- [ ] `add_newline = false` + `show_always = true` + no other modules

### Defer to v4.0

- [ ] `nerv.swap.zram.swapDevices` option — not needed; 1 is always correct for current scope
- [ ] `nerv.swap.zram.algorithm` option — not needed; zstd is correct; escape hatch via `lib.mkForce`
- [ ] Starship directory or git modules as opt-in flags — user responsibility via dotfiles

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `nerv.swap.zram.enable` | HIGH — BTRFS profile has no swap partition | LOW | P1 |
| `nerv.swap.zram.memoryPercent` | MEDIUM — sensible default covers most cases | LOW | P1 |
| Starship two-line prompt | HIGH — current bare PS1 is a usability gap | LOW | P1 |
| Error color on `$` | MEDIUM — adds feedback without clutter | LOW | P1 |
| `nerv.swap.zram.algorithm` option | LOW — zstd is always correct | LOW | P3 |
| Full starship modules (git, dir, etc.) | LOW for system defaults — user concern | HIGH (latency risk) | P3 |

---

## Sources

- [zramSwap module options — MyNixOS](https://mynixos.com/options/zramSwap) — HIGH confidence
- [zramSwap.algorithm — MyNixOS](https://mynixos.com/nixpkgs/option/zramSwap.algorithm) — HIGH confidence (default "zstd", valid enum values listed)
- [Configuring zram and zswap for optimal performance — NixOS Discourse](https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852) — MEDIUM confidence (community consensus)
- [zramswap.memoryPercent is incorrect or at least misleading — nixpkgs #103106](https://github.com/NixOS/nixpkgs/issues/103106) — HIGH confidence (explains compression ratio behavior)
- [zramSwap.memoryMax capped at 50% bug — nixpkgs #435031](https://github.com/nixos/nixpkgs/issues/435031) — HIGH confidence (known open bug, reported 2025-08-19)
- [Starship prompt configuration — starship.rs/config](https://starship.rs/config/) — HIGH confidence (official docs: format strings, username styles, character module)
- [programs.starship NixOS wiki](https://wiki.nixos.org/wiki/Starship) — MEDIUM confidence
- [programs.starship options — MyNixOS (nixpkgs system level)](https://mynixos.com/options/programs.starship) — HIGH confidence (enable, settings, enableZshIntegration confirmed)
- [nixpkgs/nixos/modules/programs/starship.nix release-25.11](https://github.com/NixOS/nixpkgs/blob/release-25.11/nixos/modules/programs/starship.nix) — HIGH confidence (NixOS 25.11 is the target stateVersion)

---

*Feature research for: nerv.nixos v3.0 — zram swap + starship prompt*
*Researched: 2026-03-12*
