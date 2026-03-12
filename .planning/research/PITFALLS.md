# Pitfalls Research: nerv.nixos v3.0

**Domain:** NixOS system configuration — adding zram swap and starship prompt to existing hardened BTRFS+impermanence system
**Researched:** 2026-03-12
**Confidence:** HIGH (zram module source verified, zsh/starship init order verified from nixpkgs release-25.11 source)

---

## Critical Pitfalls

### P1 — Declaring swapDevices Alongside zramSwap (Module Conflict)

**What goes wrong:**
The BTRFS host currently declares no swap (correct — P9 in v2.0 research established that BTRFS CoW subvolumes cannot host swap files). If someone adds a traditional `swapDevices` entry alongside `zramSwap.enable = true`, the kernel ends up with two active swap sources competing for priority, and NixOS may override or ignore zram priority settings. More critically: using `swapDevices = lib.mkForce []` to clear hardware-generated swap entries can interact badly with the zram module's own device management.

**Why it happens:**
`nixos-generate-config` sometimes emits `swapDevices` entries for detected swap partitions. Operators copy this into configuration without realising zram is meant to replace — not augment — a swap partition. The LVM server profile already declares a swap LV via disko; if the `nerv.swap.zram.enable` option is ever set on a server profile, it would create two active swap sources.

**How to avoid:**
- The `nerv.swap.zram` option must assert `nerv.disko.layout == "btrfs"` — or at minimum emit a warning if layout is LVM (which already has a disk-based swap LV).
- Do not declare `swapDevices` in any module when zram is enabled.
- The BTRFS disko branch already declares no swap (confirmed in disko.nix). No additional `swapDevices` entry should appear in the module.

**Warning signs:**
`swapon --show` after boot lists both a `/dev/zram0` and a block device. `systemctl status dev-zram0.swap` shows active alongside another `.swap` unit.

**Phase to address:** Phase implementing `modules/system/swap.nix` (zram module). Add an assertion blocking simultaneous LVM layout + zram enable.

---

### P2 — Starship's eval Injected via programs.zsh.promptInit (Runs After Plugins — Correct, But Fragile)

**What goes wrong:**
`programs.starship.enable = true` in NixOS system config injects starship's init via `programs.zsh.promptInit` (when the default `interactiveOnly = true` is in effect). The generated `/etc/zshrc` ordering is:

1. `programs.zsh.interactiveShellInit` (syntax-highlighting, history-substring-search, bindings, TERM check, fzf)
2. Shell aliases
3. `programs.zsh.promptInit` (starship init runs here)

This ordering is correct — starship init must come after plugins. However: if `interactiveOnly` is ever set to `false`, the init moves to `programs.zsh.shellInit`, which runs before `interactiveShellInit`. At that point, starship initialises before the plugins load, breaking history-substring-search's ZLE widget wrapping.

**Why it happens:**
The `interactiveOnly` option is not obvious, and some guides suggest disabling it for tools that need to be active in non-interactive shells. Operators changing this flag do not realise it repositions the starship init block relative to the plugin chain.

**How to avoid:**
Never set `programs.starship.interactiveOnly = false`. Leave it at the default (`true`) so the init lands in `promptInit` — which is after all interactiveShellInit content. Document this constraint as a comment in the starship block of zsh.nix.

**Warning signs:**
After toggling `interactiveOnly = false`: the prompt appears but history-substring-search (up/down arrow key history search) stops working. The symptom is that `^[[A` and `^[[B` bindings no longer invoke `history-substring-search-up/down`.

**Phase to address:** Phase adding starship to `modules/services/zsh.nix`. Comment in code must lock `interactiveOnly = true`.

---

### P3 — Manual `eval "$(starship init zsh)"` in interactiveShellInit Conflicts With programs.starship.enable

**What goes wrong:**
If `programs.starship.enable = true` is set AND a manual `eval "$(starship init zsh)"` appears anywhere in `programs.zsh.interactiveShellInit`, starship initialises twice. The second init clobbers ZLE hooks set by the first, breaking prompt rendering in edge cases (transient prompt, continuation PS2).

**Why it happens:**
Operators who previously used a manual eval pattern (common in pre-nixpkgs-module era configs) do not remove it when switching to `programs.starship.enable`. The system compiles without error — both are valid shell expressions.

**How to avoid:**
Use `programs.starship.enable = true` exclusively. Do not add any `eval "$(starship init zsh)"` or `source ... starship.zsh` to `interactiveShellInit`. The NixOS module handles the full init lifecycle.

**Warning signs:**
`zsh -xi 2>&1 | grep starship` shows the starship binary being invoked twice during shell startup.

**Phase to address:** Phase adding starship to `modules/services/zsh.nix`. The implementation must not touch interactiveShellInit for the starship init call.

---

### P4 — Starship Disabled by Existing TERM Fallback Check (Prompt Never Appears on Some Terminals)

**What goes wrong:**
The existing `interactiveShellInit` in zsh.nix includes:
```bash
if ! infocmp "$TERM" &>/dev/null 2>&1; then
  export TERM=xterm-256color
fi
```
This runs early in `interactiveShellInit` (block 1 in /etc/zshrc). The starship init runs later in `promptInit` (block 3). Starship's own guard is:
```bash
if [[ $TERM != "dumb" ]]; then
  eval "$(starship init zsh)"
fi
```
These two checks are compatible — the TERM fallback fires first, setting a valid term, and starship's dumb-term guard passes. No conflict.

However: if the TERM fallback is ever moved to `.zshenv` or `.zprofile` (outside the NixOS-managed /etc/zshrc), it may not fire before starship's check in some terminal configurations. The current placement is correct and must be preserved.

**Why it happens:**
The TERM override is a guard against terminals like Ghostty whose terminfo entry is not on the server. If someone "cleans up" zsh config and relocates this guard, they silently break starship in those terminal types.

**How to avoid:**
Keep the `infocmp` TERM fallback in `interactiveShellInit` exactly where it is. Starship's own guard (`$TERM != "dumb"`) is independent and poses no conflict with the existing check. Document both guards as intentional.

**Warning signs:**
No prompt rendered when connecting via Ghostty or another terminal whose TERM entry is absent from the server's terminfo database, after relocating the TERM fallback.

**Phase to address:** Phase adding starship to `modules/services/zsh.nix`. Verify TERM compatibility in test notes.

---

### P5 — zramSwap.memoryPercent vs memoryMax: Double-Sizing Trap

**What goes wrong:**
`zramSwap.memoryPercent` defaults to 50 (50% of RAM). `zramSwap.memoryMax` is an absolute byte limit. When the `nerv.swap.zram.size` option is wired to `zramSwap.memoryMax`, operators must be aware that if both `memoryPercent` and `memoryMax` are set, the zram module uses whichever is smaller. A low `memoryMax` value silently caps the zram device below the `memoryPercent` expectation.

The v3.0 requirement specifies `nerv.swap.zram.size` as an option in MB, defaulting to half RAM. If this wires to `memoryMax`, operators who also expect the default `memoryPercent = 50` behaviour will get a confusingly small device on machines with large RAM, because `memoryMax` takes effect first.

**Why it happens:**
The zram NixOS module docs describe `memoryMax` as "maximum total amount of memory in bytes." It is easy to conflate "max" with "size" and set both without realising the "smaller wins" semantics.

**How to avoid:**
Implement `nerv.swap.zram.size` wired to `zramSwap.memoryMax` only, and explicitly set `zramSwap.memoryPercent = 100` to make `memoryMax` the effective ceiling. This gives operators a predictable MB-based size option without the percentage logic interfering. Document the "smaller wins" rule in the option description.

Alternatively, wire to `memoryPercent` and rename the nerv option to `zramPercent` for clarity. Either is valid; the critical thing is documenting which semantics apply so operators are not surprised.

**Warning signs:**
`zramctl` shows the zram device significantly smaller than expected. `cat /proc/swaps` shows a smaller device than the configured nerv option value.

**Phase to address:** Phase implementing `modules/system/swap.nix`. Option description must document the sizing semantics explicitly.

---

### P6 — zram Does Not Require Impermanence Handling (Non-Pitfall to Be Aware Of)

**What goes wrong:**
Operators new to zram sometimes ask whether the zram device needs persistence entries or whether it survives BTRFS rollback. It does not — and does not need to. zram is a kernel memory subsystem: `/dev/zram0` is created at boot by `zram-generator` (via the `zramSwap` NixOS module), configured in `/etc/systemd/zram-generator.conf`, and torn down on shutdown. There is no on-disk state to persist.

The only failure mode is: an operator adds `/dev/zram0` or a related path to `environment.persistence` or `nerv.impermanence.extraDirs`. This is incorrect and will either error or have no effect, since zram exists only in RAM.

**Why it happens:**
Operators see other `/dev` or `/var/lib` entries in the persistence config and copy the pattern without understanding that zram is ephemeral-by-design.

**How to avoid:**
Do not add any zram-related path to `environment.persistence` or `nerv.impermanence`. The `modules/system/swap.nix` module should not touch `environment.persistence` at all.

**Warning signs:**
`nix flake check` warns about a missing or non-existent path in persistence config. Or: persistence bind-mount fails for a zram-related path.

**Phase to address:** Phase implementing `modules/system/swap.nix`. No persistence wiring needed — document this absence as intentional.

---

### P7 — Starship Cache Directory Lost on BTRFS Rollback (Non-Blocking, Cosmetic)

**What goes wrong:**
Starship writes a timing cache to `$XDG_CACHE_HOME/starship/` (typically `~/.cache/starship/`). On BTRFS rollback, `$HOME` is on the `@home` subvolume which is NOT rolled back (rollback resets `@` root only). So the starship cache in `~/.cache/` survives across reboots correctly.

The only scenario where cache is lost: if an operator mounts `$HOME/.cache` as a per-user impermanence tmpfs via `nerv.impermanence.users.<name>`. In that case, the starship module directory cache is cleared on reboot, causing a brief cold-start delay (starship recomputes module availability). This is cosmetic — the prompt still works.

**Why it happens:**
Operators mount `~/.cache` as tmpfs to avoid accumulating stale caches across time, which is a valid choice. The consequence for starship is minor but can be surprising.

**How to avoid:**
No action required in the nerv library. Document in the option description for `nerv.impermanence.users` that mounting `~/.cache` as tmpfs clears starship's timing cache. This is a user-configuration concern, not a library concern.

**Warning signs:**
Starship prompt has a brief additional delay on first shell open after reboot. Non-blocking.

**Phase to address:** No phase required. Document as a known behavior in the starship module comment.

---

### P8 — zram Algorithm Choice: zstd Default Is Correct, But init_on_free Adds CPU Cost

**What goes wrong:**
The existing `kernel.nix` sets `init_on_free=1` — memory is zeroed when freed. zram compresses pages in memory and decompresses them on swap-in. When a page is freed from zram (decompressed and returned to the page pool), `init_on_free` zeros it. Combined with zstd compression (the NixOS default), this adds CPU overhead: decompress + zero vs. just decompress.

This is not a stability issue — it is correct behavior. But on memory-constrained systems under heavy swap pressure, the additional zeroing of freed pages can cause noticeable throughput reduction. The lz4 algorithm compresses/decompresses faster and reduces the window in which `init_on_free` zeroing adds latency.

**Why it happens:**
The kernel hardening settings in `kernel.nix` were set for security without considering the zram interaction. They are correct independently; together they increase CPU cost under heavy swap.

**How to avoid:**
For the BTRFS desktop profile (Zen kernel, already performance-tuned), keep the NixOS zram default of zstd. The security benefit of `init_on_free` outweighs the performance cost for typical desktop use (occasional swap, not sustained pressure). Document the tradeoff in the swap module comment.

If a future operator wants to override to lz4 for lower latency, expose this via `nerv.swap.zram.algorithm` (enum, default "zstd").

**Warning signs:**
Under heavy swap pressure (e.g., many browser tabs + build), CPU utilisation spikes above baseline expectation. `vmstat 1` shows high `si`/`so` (swap in/out) with corresponding high `us` (user CPU). Not a failure — context-dependent tradeoff.

**Phase to address:** Phase implementing `modules/system/swap.nix`. Expose `algorithm` option with zstd default.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode `memoryPercent = 50` without an option | No option API needed | Operators cannot tune zram size without forking | Never — expose as `nerv.swap.zram.memoryPercent` at minimum |
| Use `eval "$(starship init zsh)"` in interactiveShellInit instead of programs.starship.enable | Avoids learning the NixOS module | Double-init on future migration; fragile ordering | Never |
| Skip zram assertion for LVM layout | Simpler implementation | Operators accidentally enable zram alongside LVM swap on server | Never — assertion costs nothing |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| zram + impermanence | Adding zram-related paths to environment.persistence | Do not — zram is RAM-only, no persistence needed |
| starship + zsh plugins | Setting interactiveOnly = false | Keep default true so starship lands in promptInit (after plugin chain) |
| zram + LVM swap | Enabling zramSwap.enable when layout = "lvm" | Assert or warn: LVM profile already has a disk swap LV |
| starship config + STARSHIP_CONFIG env var | NixOS module sets STARSHIP_CONFIG to nix store path only if no ~/.config/starship.toml exists | Do not set STARSHIP_CONFIG manually; let the NixOS module manage it |
| zramSwap.memoryMax + memoryPercent | Setting both without knowing "smaller wins" | Wire nerv option to memoryMax only; set memoryPercent = 100 to neutralise it |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| zram device too small (memoryMax misconfigured) | Swap exhausted quickly under load; OOM killer fires | Wire nerv size option to memoryMax; document MB semantics | Any time available RAM exceeds 2x memoryMax |
| Double starship init | Extra ~10-20ms on shell startup; ZLE hook duplication in edge cases | Use programs.starship.enable only; no manual eval | Any shell open; worsens with slow hardware |
| zstd + init_on_free under heavy swap | CPU spike during sustained swap pressure | Expected tradeoff; document it; offer lz4 override option | Systems with <8GB RAM under heavy concurrent workload |

---

## "Looks Done But Isn't" Checklist

- [ ] **zram module**: Verify `swapon --show` after boot shows `/dev/zram0` with correct size, not a block device
- [ ] **zram module**: Verify `zramctl` shows correct algorithm (zstd by default)
- [ ] **zram assertion**: Verify `nix flake check` errors when `nerv.swap.zram.enable = true` AND `nerv.disko.layout = "lvm"`
- [ ] **starship**: Verify arrow-key history-substring-search still works after adding starship (plugins not broken)
- [ ] **starship**: Verify prompt renders correctly in both local terminal and SSH via xterm-256color fallback
- [ ] **starship config**: Verify `$STARSHIP_CONFIG` points to nix store path (not missing) — `echo $STARSHIP_CONFIG` in shell
- [ ] **zram + impermanence**: Confirm no zram paths appear in environment.persistence — check with `nixos-option environment.persistence`
- [ ] **interactiveOnly**: Confirm programs.starship.interactiveOnly = true (default) not overridden — check /etc/zshrc for starship in promptInit section not interactiveShellInit

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Double starship init | LOW | Remove manual eval from interactiveShellInit; nixos-rebuild switch |
| zram wrong size | LOW | Update nerv.swap.zram.size; nixos-rebuild switch; reboot (memoryPercent/Max change does not hot-reload — see nixpkgs issue #410597) |
| LVM swap + zram active simultaneously | LOW | Disable nerv.swap.zram.enable on server; nixos-rebuild switch; reboot |
| starship interactiveOnly = false (plugin breakage) | LOW | Revert to default (true) or remove the option; nixos-rebuild switch |
| TERM conflict with starship | LOW | Verify infocmp TERM check is in interactiveShellInit (block 1), starship init in promptInit (block 3) — check /etc/zshrc order |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| P1 — swapDevices + zramSwap conflict | Phase: swap.nix module | `nix flake check` passes; `swapon --show` shows only zram0 |
| P2 — interactiveOnly = false breaks plugin order | Phase: zsh.nix starship integration | Arrow-key history search works after adding starship |
| P3 — Double starship init | Phase: zsh.nix starship integration | Only one starship invocation in /etc/zshrc |
| P4 — TERM check + starship compatibility | Phase: zsh.nix starship integration | Prompt renders on Ghostty/xterm-256color fallback terminals |
| P5 — memoryMax + memoryPercent sizing | Phase: swap.nix module | `zramctl` shows expected device size; document semantics |
| P6 — zram does not need persistence (non-pitfall) | Phase: swap.nix module | No persistence entries for zram — confirmed by code review |
| P7 — starship cache + user tmpfs impermanence | User documentation only | Noted in module comment; no code change needed |
| P8 — zstd + init_on_free CPU cost | Phase: swap.nix module | Expose algorithm option; document tradeoff in comment |

---

## Sources

- `modules/services/zsh.nix` (confirmed plugin load order: syntax-highlighting → history-substring-search → fzf → TERM check, all in interactiveShellInit)
- `modules/system/disko.nix` (confirmed BTRFS branch has no swapDevices; LVM branch has swap LV)
- `modules/system/kernel.nix` (confirmed init_on_free=1 active — affects zram CPU cost)
- `modules/system/impermanence.nix` (confirmed /var/lib broad persistence; zram needs no entries)
- nixpkgs release-25.11 `nixos/modules/programs/starship.nix` — confirms `programs.zsh.promptInit` used when interactiveOnly=true (default); no enableZshIntegration separate option
- nixpkgs release-25.11 `nixos/modules/programs/zsh/zsh.nix` — confirms /etc/zshrc order: interactiveShellInit → aliases → promptInit
- nixpkgs master `nixos/modules/config/zram.nix` — confirms algorithm list (lzo/lz4/lz4hc/zstd/842), memoryPercent default 50%, memoryMax "smaller wins" semantics, swapDevices option default 1
- [NixOS Discourse: zram breaking when own device exists](https://discourse.nixos.org/t/how-to-prevent-own-zram-device-from-breaking-zramswap/66486) — device resource conflict pattern
- [nixpkgs issue #410597](https://github.com/NixOS/nixpkgs/issues/410597) — memoryPercent change does not hot-reload; reboot required

---
*Pitfalls research for: nerv.nixos v3.0 — zram swap + starship prompt*
*Researched: 2026-03-12*
