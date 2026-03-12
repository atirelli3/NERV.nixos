# Project Research Summary

**Project:** nerv.nixos v3.0 — zram swap + starship prompt
**Domain:** NixOS flake library — composable system module extension
**Researched:** 2026-03-12
**Confidence:** HIGH

## Executive Summary

nerv.nixos v3.0 adds two narrowly-scoped improvements to the existing hardened NixOS library: in-memory compressed swap via the `zramSwap` NixOS module, and a minimal two-line starship prompt integrated into `nerv.zsh`. Both features are delivered entirely through built-in nixpkgs modules — no new flake inputs, no external dependencies. The implementation surface is small: one new file (`modules/system/swap.nix`) and one modification (`modules/services/zsh.nix`). Research confirms both features map cleanly onto well-documented NixOS primitives with verified option names, defaults, and injection mechanics from nixpkgs release-25.11 source.

The recommended approach is to implement zram first (lower risk, fully independent, immediately verifiable with `swapon --show`) then add starship (touches an already-tested file, benefits from a clean diff). zram fills a real gap: the BTRFS host profile deliberately has no swap partition, leaving the system without any swap. Starship replaces the bare default PS1 with a prompt that shows username and provides error feedback via `$` color change — without powerline fonts or prompt modules that belong in user dotfiles. Both features are opt-in via `nerv.*` options defaulting to false, consistent with the library's existing pattern.

The primary risks are ordering-related, not functional. The zram module must guard against being enabled alongside the LVM layout's existing disk swap LV (an assertion in `swap.nix` is the correct prevention). The starship integration must use `programs.starship.enable` exclusively and never touch `interactiveShellInit` directly — the NixOS module manages the zsh init lifecycle via `promptInit`, which runs after the existing plugin chain. Both risks are fully understood and have straightforward preventions documented in the pitfalls research.

---

## Key Findings

### Recommended Stack

Both features use built-in NixOS modules. No additional flake inputs are needed for either feature. The relevant modules are `zramSwap` (backed by `services.zram-generator`) and `programs.starship` (injects into `programs.zsh.promptInit`), both present and verified in nixpkgs release-25.11.

**Core technologies:**
- `zramSwap` NixOS module (built-in): in-memory compressed swap — BTRFS-safe, no filesystem swap file, activates via systemd at boot
- `programs.starship` NixOS module (built-in, starship 1.24.2): system-wide prompt with declarative TOML config — injects into `/etc/zshrc` via `promptInit` hook automatically

**Critical option mapping note:** `nerv.swap.zram.size` (if exposed in MB) must wire to `zramSwap.memoryMax` with `zramSwap.memoryPercent = 100` to neutralise the "smaller wins" semantics. The simpler and recommended approach is to expose only `nerv.swap.zram.memoryPercent`, which maps directly to `zramSwap.memoryPercent` with no conversion arithmetic and no interaction bugs.

### Expected Features

**Must have (v3.0 scope):**
- `nerv.swap.zram.enable` (default: false) — activates zramSwap with zstd algorithm, priority 100, 1 swap device
- `nerv.swap.zram.memoryPercent` (default: 50) — passes through to `zramSwap.memoryPercent`; 50% is correct because compression ratio means actual RAM consumption is ~15-25% of physical RAM
- Starship prompt in `modules/services/zsh.nix` — enabled when `nerv.zsh.enable = true`; adds `nerv.zsh.starship.enable` sub-option (default: false)
- Two-line prompt format: dim cyan username on line 1, white `$` on line 2; `$` turns red on non-zero exit code
- `add_newline = false` + `show_always = true` + no other starship modules (git, directory, etc. belong in user dotfiles)

**Should have (differentiators):**
- BTRFS-safe swap: zram fills the swap gap that BTRFS CoW prevents from being solved with a swap file, without touching disko layout
- Prompt survives impermanence rollback: `programs.starship` writes `/etc/starship.toml` to the Nix store — rebuilt on every `nixos-rebuild switch`, immune to root subvolume rollback
- Per-user override: if `~/.config/starship.toml` exists, the NixOS module skips setting `STARSHIP_CONFIG` — user config takes precedence with no library changes required
- LVM + zram assertion: warn or error when `nerv.swap.zram.enable = true` on a server profile that already has a disk swap LV

**Defer to v4.0:**
- `nerv.swap.zram.algorithm` option — zstd is correct for all current use cases; `lib.mkForce "lz4"` is the escape hatch for power users
- `nerv.swap.zram.swapDevices` option — 1 is always correct; `lib.mkForce 2` is the escape hatch
- Starship directory or git modules as opt-in nerv flags — user responsibility via dotfiles or Home Manager

### Architecture Approach

The implementation requires exactly 3 file touches: a new `modules/system/swap.nix`, one-line addition to `modules/system/default.nix` (import), and a modification to `modules/services/zsh.nix` (add starship sub-option and config block). No other files change. The architecture research confirms two governing structural decisions: swap belongs in `modules/system/` (kernel/memory concern, not a daemon), and starship belongs nested inside `zsh.nix` (not a separate service file) to structurally enforce the dependency that starship requires `programs.zsh.enable = true`.

**Major components:**
1. `modules/system/swap.nix` (NEW) — declares `nerv.swap.zram.{enable,memoryPercent}` options; gates `zramSwap.*` config block behind `lib.mkIf cfg.enable`; includes LVM layout assertion
2. `modules/system/default.nix` (MODIFIED) — adds `./swap.nix` import before `./secureboot.nix` (ordering convention preserved)
3. `modules/services/zsh.nix` (MODIFIED) — adds `nerv.zsh.starship.enable` sub-option and `programs.starship` config block inside the existing `lib.mkIf cfg.enable` guard

### Critical Pitfalls

1. **swapDevices conflict with zramSwap** (P1) — if `swapDevices` entries coexist with `nerv.swap.zram.enable`, swap priority semantics become unpredictable. Prevention: assert `nerv.disko.layout != "lvm"` when zram is enabled; BTRFS disko branch already declares no `swapDevices` entries.

2. **Double starship init** (P3) — adding `eval "$(starship init zsh)"` to `interactiveShellInit` alongside `programs.starship.enable = true` runs starship init twice, clobbering ZLE hooks. Prevention: use only `programs.starship.enable = true`; never touch `interactiveShellInit` for starship.

3. **interactiveOnly = false breaks plugin order** (P2) — setting `programs.starship.interactiveOnly = false` moves starship init from `promptInit` (block 3 in `/etc/zshrc`) to `shellInit` (block 1), before the plugin chain loads, breaking `history-substring-search` ZLE bindings. Prevention: never set `interactiveOnly = false`; leave at the default `true`.

4. **memoryMax + memoryPercent sizing trap** (P5) — both options active with "smaller wins" semantics silently produces a smaller zram device than expected. Prevention: wire nerv option to `memoryPercent` only (recommended), or if `memoryMax` is used, explicitly set `memoryPercent = 100` to neutralise the percentage cap.

5. **init_on_free CPU cost under heavy swap** (P8) — existing `kernel.nix` sets `init_on_free=1`; combined with zstd decompression under heavy swap pressure, this adds CPU overhead. Non-blocking for desktop use; document the tradeoff in a module comment.

---

## Implications for Roadmap

Two phases are sufficient for v3.0. The features are independent enough to implement and verify separately, which reduces risk and keeps diffs clean.

### Phase 1: zram Swap Module

**Rationale:** New file with zero dependencies on other in-flight work. Immediately verifiable with a `nixos-rebuild test` and `swapon --show`. Lower risk than touching an existing production file. Establishes the `nerv.swap.*` option namespace cleanly.

**Delivers:** `modules/system/swap.nix` with `nerv.swap.zram.{enable,memoryPercent}` options; `zramSwap` configured with zstd algorithm, priority 100, 1 device; LVM layout assertion; one-line import in `modules/system/default.nix`.

**Addresses:** Table-stakes features — `nerv.swap.zram.enable`, `nerv.swap.zram.memoryPercent`, BTRFS-safe in-memory swap.

**Avoids:** P1 (swapDevices conflict — assert LVM + zram combination), P5 (sizing trap — use `memoryPercent` not `memoryMax`), P6 (no persistence entries for zram — module must not touch `environment.persistence`).

**Verification:** `swapon --show` lists `/dev/zram0` with expected size; `zramctl` shows zstd algorithm; `nix flake check` errors on LVM + zram combination.

### Phase 2: Starship Prompt Integration

**Rationale:** Touches existing production `zsh.nix`. Benefits from a clean diff against a known-working base (post-Phase 1). The starship config requires writing a TOML attrset and verifying prompt aesthetics — cleaner to do this as a focused, isolated change.

**Delivers:** `nerv.zsh.starship.enable` sub-option (default: false) in `modules/services/zsh.nix`; `programs.starship` config block with two-line format, dim cyan username, white/red `$`; no other starship modules; `add_newline = false`, `show_always = true`.

**Addresses:** Table-stakes features — starship prompt in zsh, two-line format, error color feedback. Differentiators — impermanence-safe prompt config, per-user override capability.

**Avoids:** P2 (interactiveOnly = true enforced by in-code comment), P3 (no manual eval in interactiveShellInit), P4 (TERM fallback in interactiveShellInit stays in place — no relocation).

**Verification:** Arrow-key history search works after enabling starship; `echo $STARSHIP_CONFIG` points to nix store path; prompt renders correctly on local terminal and SSH with xterm-256color fallback.

### Phase Ordering Rationale

- zram first because it is a new file — mistakes are isolated and reversible without touching anything already working.
- Starship second because it modifies a production file — a clean base makes the diff smaller and review easier.
- No Phase 3 needed: both features are fully independent of each other and of any other v3.0 scope item. The defer list (algorithm option, per-user starship flags) goes to v4.0 backlog.

### Research Flags

Phases with well-documented patterns (skip research-phase during planning):
- **Phase 1 (zram):** Option names, types, defaults, and systemd activation sequence verified from nixpkgs release-25.11 source. The `lib.mkIf`/`options` pattern is established nerv convention. No additional research needed.
- **Phase 2 (starship):** Injection mechanics, load order, and TOML config format verified from nixpkgs source and starship.rs/config. The sub-option nesting pattern is established nerv convention. No additional research needed.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Option names, types, defaults, and module mechanics verified directly from nixpkgs release-25.11 source (`zram.nix`, `starship.nix`) |
| Features | HIGH | Feature scope is narrow and aligns with verified NixOS module capabilities; memoryPercent semantics confirmed via nixpkgs issue #103106 |
| Architecture | HIGH | Build order and file boundaries derived from existing nerv patterns (boot.nix/disko.nix split) and verified injection order from project `zsh.nix` source |
| Pitfalls | HIGH | `/etc/zshrc` load order and `promptInit` vs `interactiveShellInit` distinction verified from nixpkgs `zsh.nix` source; zram sizing semantics confirmed from nixpkgs issue #435031 |

**Overall confidence:** HIGH

### Gaps to Address

- **`nerv.swap.zram.size` vs `memoryPercent` naming:** FEATURES.md references a `nerv.swap.zram.size` (in MB) option, but research recommends using `memoryPercent` to avoid the `memoryMax` sizing trap (P5). The roadmap phase should resolve this naming decision before implementation. Recommendation: expose `memoryPercent` only for v3.0; defer MB-based sizing to v4.0 if operators request it.
- **LVM + zram assertion strength:** Whether to hard-error (assertion that fails evaluation) or emit a `lib.warn` when zram is enabled on LVM layout needs a decision at implementation time. A hard error is safer for this combination.
- **`zramSwap.priority = 5` vs `100`:** STACK.md notes the nixpkgs default is 5; FEATURES.md recommends 100 for "prefer zram." Since the LVM assertion will prevent zram + disk swap coexistence, either value is functionally correct for the BTRFS profile. Record the chosen value in implementation notes.

---

## Sources

### Primary (HIGH confidence)

- `https://raw.githubusercontent.com/NixOS/nixpkgs/release-25.11/nixos/modules/config/zram.nix` — verified `zramSwap.*` option names, types, defaults, and `services.zram-generator` delegation
- `https://raw.githubusercontent.com/NixOS/nixpkgs/release-25.11/nixos/modules/programs/starship.nix` — verified `programs.starship.*` options, `initOption` logic, exact `promptInit` injection code
- `https://raw.githubusercontent.com/NixOS/nixpkgs/release-25.11/nixos/modules/programs/zsh/zsh.nix` — verified `/etc/zshrc` load order: `interactiveShellInit` then aliases then `promptInit`
- `modules/services/zsh.nix` (project source) — confirmed plugin chain in `interactiveShellInit`; no conflict with `promptInit`
- `modules/system/disko.nix` (project source) — confirmed BTRFS branch has no `swapDevices`; LVM branch has swap LV
- `modules/system/kernel.nix` (project source) — confirmed `init_on_free=1` active
- `https://mynixos.com/nixpkgs/options/zramSwap` — option reference
- `https://mynixos.com/options/programs.starship` — option reference
- `https://starship.rs/config/` — starship format strings, username and character module config

### Secondary (MEDIUM confidence)

- `https://discourse.nixos.org/t/configuring-zram-and-zswap-parameters-for-optimal-performance/47852` — zstd vs lz4 community consensus; zram + zswap interaction patterns
- `https://wiki.nixos.org/wiki/Starship` — `programs.starship` NixOS integration overview
- `https://mynixos.com/nixpkgs/package/starship` — starship 1.24.2 version confirmation

### Tertiary (issue trackers — HIGH confidence for specific bugs)

- `https://github.com/NixOS/nixpkgs/issues/103106` — `zramSwap.memoryPercent` compression ratio clarification (50% memoryPercent results in ~15-25% physical RAM consumed)
- `https://github.com/nixos/nixpkgs/issues/435031` — `zramSwap.memoryMax` silently capped at 50% of RAM (open bug, reported 2025-08-19)
- `https://github.com/NixOS/nixpkgs/issues/410597` — `memoryPercent` change does not hot-reload; reboot required after changing zram size

---
*Research completed: 2026-03-12*
*Ready for roadmap: yes*
