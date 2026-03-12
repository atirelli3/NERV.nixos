# Phase 14: zram Swap Module - Research

**Researched:** 2026-03-12
**Domain:** NixOS zramSwap module, NixOS module assertion patterns
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Extend `modules/system/disko.nix` (not a new swap.nix) — option namespace `nerv.disko.btrfs.zram.*` is already scoped to disko; co-location makes the BTRFS constraint self-documenting
- Add `btrfs.zram` as a sub-attribute inside the existing `options.nerv.disko` block, alongside `lvm.*`
- zram config (`zramSwap = { ... }`) is appended inside the existing `lib.mkIf isBtrfs` branch
- `nerv.disko.btrfs.zram.enable` — `lib.types.bool`, default `false`
- `nerv.disko.btrfs.zram.memoryPercent` — `lib.types.ints.between 1 100`, default `50`
- memoryPercent (not MB) — avoids nixpkgs #435031 memoryMax+memoryPercent interaction bug; MB-based option deferred to v4.0 (SWAP-05)
- `zramSwap.priority = 100` — explicitly prefer zram over any other swap source
- `zramSwap.algorithm = "zstd"` — hardcoded in v3.0; `lib.mkForce` escape hatch for users who need to override
- No device count option — single `/dev/zram0` is sufficient; nixpkgs `numDevices` default is fine
- Assertion fires when `cfg.btrfs.zram.enable = true` AND layout is not btrfs — uses `lib.mkIf cfg.btrfs.zram.enable` pattern, evaluated on all layouts
- Error message text defined in CONTEXT.md (verbatim multi-line string)
- No changes to `modules/system/default.nix`, `flake.nix`, or any other module
- Add inline comment near zram block noting `init_on_free=1` CPU overhead interaction with zstd decompression

### Claude's Discretion

- Exact option description wording for `memoryPercent` (nixpkgs-style prose vs brief)
- Whether to include an `example` value in the option definition for `memoryPercent`
- Ordering of zramSwap attributes within the config block

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SWAP-01 | User can enable zram compressed swap via `nerv.disko.btrfs.zram.enable` (default: false, BTRFS layout only) | `zramSwap.enable` is a top-level NixOS option requiring no import; wired via `lib.mkIf isBtrfs` and `lib.mkIf cfg.btrfs.zram.enable` guards |
| SWAP-02 | User can configure zram device size as percent of RAM via `nerv.disko.btrfs.zram.memoryPercent` (default: 50) | `zramSwap.memoryPercent` accepts a positive integer (nixpkgs default: 50); pass-through is direct assignment |
| SWAP-03 | System raises a hard evaluation error when `nerv.disko.btrfs.zram.enable = true` on LVM layout | `config.assertions` list with `assertion = isBtrfs` and informative `message`; fires at `nixos-rebuild`/`nix flake check` eval time |
</phase_requirements>

## Summary

Phase 14 adds two NixOS options (`nerv.disko.btrfs.zram.enable` and `nerv.disko.btrfs.zram.memoryPercent`) to the existing `modules/system/disko.nix` and wires them to the built-in `zramSwap` NixOS top-level option. The `zramSwap` module is provided by nixpkgs with no additional imports required. All implementation is confined to a single file with a single-plan scope.

The primary technical concern is the assertion pattern. The CONTEXT.md references `lib.mkAssert` which does NOT exist in nixpkgs. The correct project pattern — used in `identity.nix`, `impermanence.nix`, and `openssh.nix` — is `config.assertions = [{ assertion = <bool>; message = "<string>"; }]`. The planner must use this form, not `lib.mkAssert`.

The secondary concern is the memoryPercent vs memoryMax interaction bug (nixpkgs #435031): when both `memoryMax` and `memoryPercent` are set, nixpkgs uses `min(memoryPercent-derived, memoryMax)`, causing the smaller value to silently win. This phase avoids the issue entirely by only setting `memoryPercent` and never setting `memoryMax`.

**Primary recommendation:** Append a nested `btrfs.zram` options block and a guarded `zramSwap` config block to the existing BTRFS branch in `disko.nix`; use `config.assertions` (not `lib.mkAssert`) for the layout-mismatch guard.

## Standard Stack

### Core

| Option | NixOS Location | Default | Notes |
|--------|----------------|---------|-------|
| `zramSwap.enable` | `nixos/modules/config/zram.nix` | `false` | No import required — included in NixOS by default |
| `zramSwap.algorithm` | same | `"zstd"` | Enum: "842", "lzo", "lzo-rle", "lz4", "lz4hc", "zstd" |
| `zramSwap.memoryPercent` | same | `50` | Positive integer; upper bound on zram size as % of total RAM |
| `zramSwap.priority` | same | `5` | Signed integer; higher = preferred over disk swap |
| `zramSwap.swapDevices` | same | `1` | Set to 1 → creates `/dev/zram0` |

### No Additional Packages Required

`zramSwap` is a kernel module (`zram`) loaded automatically by the NixOS module when enabled. No userspace packages need to be added to `environment.systemPackages`.

## Architecture Patterns

### Where to Insert in disko.nix

```
options.nerv.disko
  layout        ← existing
  lvm.*         ← existing
  btrfs.zram.*  ← NEW: add here, mirroring lvm.* structure

config = lib.mkMerge [
  assertion entry  ← NEW FIRST: lib.mkIf cfg.btrfs.zram.enable { assertions = [...]; }
  BTRFS branch     ← existing + append zramSwap block inside
  LVM branch       ← existing, unchanged
]
```

### Pattern 1: Options Block (mirrors lvm.*)

The existing `lvm` sub-attrset in `options.nerv.disko` is the direct template:

```nix
# Source: modules/system/disko.nix lines 49-68 (existing lvm pattern)
lvm = {
  swapSize = lib.mkOption {
    type        = lib.types.str;
    default     = "PLACEHOLDER";
    description = "...";
    example     = "16G";
  };
  ...
};
```

New `btrfs.zram` block follows identical structure:

```nix
btrfs.zram = {
  enable = lib.mkOption {
    type        = lib.types.bool;
    default     = false;
    description = "Enable zram compressed swap (BTRFS layout only). Creates /dev/zram0 sized at memoryPercent of physical RAM.";
  };
  memoryPercent = lib.mkOption {
    type        = lib.types.ints.between 1 100;
    default     = 50;
    description = "Maximum zram swap size as a percentage of total RAM. Prefer lower values (25–50) on systems with ≥ 16 GiB.";
    example     = 25;
  };
};
```

### Pattern 2: Assertion (uses project-standard config.assertions)

The project pattern from `identity.nix` and `impermanence.nix` is `config.assertions = [{ assertion = <bool>; message = "<string>"; }]`. This is placed as the first entry in `lib.mkMerge`:

```nix
# Source: modules/system/identity.nix lines 48-51 (existing assertion pattern)
config = lib.mkMerge [
  {
    assertions = [{
      assertion = config.nerv.hostname != "";
      message   = "nerv.hostname must not be empty string.";
    }];
    ...
  }
  ...
];
```

For this phase, the assertion is guarded by `lib.mkIf cfg.btrfs.zram.enable` so it only fires when the option is enabled:

```nix
config = lib.mkMerge [

  # ── zram layout guard (evaluated on all layouts when zram.enable = true) ──
  (lib.mkIf cfg.btrfs.zram.enable {
    assertions = [{
      assertion = isBtrfs;
      message   = ''
        nerv: nerv.disko.btrfs.zram.enable requires
          nerv.disko.layout = "btrfs".
          The LVM layout provides disk-based swap via the swap LV.
          Disable zram or switch to the btrfs layout.
      '';
    }];
  })

  # ── BTRFS branch ───────────────────────────────────────────────────────────
  (lib.mkIf isBtrfs {
    ...existing BTRFS content...

    # ── zram compressed swap (BTRFS only) ────────────────────────────────────
    zramSwap = lib.mkIf cfg.btrfs.zram.enable {
      enable        = true;
      memoryPercent = cfg.btrfs.zram.memoryPercent;
      priority      = 100;  # prefer zram over any other swap source
      # algorithm hardcoded to zstd in v3.0; use lib.mkForce to override.
      # Note: kernel.nix sets init_on_free=1. zstd decompression under heavy
      # swap load adds CPU overhead — acceptable on desktop but worth monitoring.
      algorithm     = lib.mkForce "zstd";
    };
  })

  # ── LVM branch ─────────────────────────────────────────────────────────────
  (lib.mkIf isLvm {
    ...existing LVM content, unchanged...
  })

];
```

### Anti-Patterns to Avoid

- **`lib.mkAssert`**: This function does not exist in nixpkgs. CONTEXT.md references it but the correct form is `config.assertions = [{ assertion = ...; message = ...; }]` as used consistently throughout this project.
- **Setting `zramSwap.memoryMax`**: Do not set this option. When combined with `memoryPercent`, nixpkgs uses `min(derived-from-percent, memoryMax)`, silently capping size. Only set `memoryPercent`.
- **Setting `zramSwap.numDevices`**: Deprecated alias for `swapDevices`. Do not use.
- **Moving zram outside the BTRFS `lib.mkIf` block**: The `zramSwap = lib.mkIf cfg.btrfs.zram.enable { ... }` config assignment should live inside the BTRFS branch. The assertion (which must fire even on LVM) is the only piece that lives at the top level of `lib.mkMerge`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Compressed in-memory swap | Custom kernel module or systemd-zram service | `zramSwap.*` NixOS options | Already implemented in nixpkgs; handles device creation, swapon, module loading |
| Assertion / evaluation error | `abort` or `builtins.throw` at top level | `config.assertions = [{ ... }]` | Module system collects and displays all assertion failures together; `throw` stops eval on first hit |

**Key insight:** `zramSwap` is fully managed by nixpkgs. The implementation is pure option wiring — no scripts, no systemd units, no packages.

## Common Pitfalls

### Pitfall 1: lib.mkAssert Does Not Exist

**What goes wrong:** Using `lib.mkIf cfg.btrfs.zram.enable (lib.mkAssert isBtrfs "…")` causes an `undefined variable` eval error.
**Why it happens:** `lib.mkAssert` is not a function in nixpkgs lib. It appeared in CONTEXT.md but is not valid Nix.
**How to avoid:** Use `config.assertions = [{ assertion = isBtrfs; message = "..."; }]` inside a `lib.mkIf cfg.btrfs.zram.enable { ... }` block — exactly as seen in `identity.nix` and `impermanence.nix`.
**Warning signs:** Eval error mentioning `undefined variable 'mkAssert'` or similar.

### Pitfall 2: memoryMax + memoryPercent Interaction

**What goes wrong:** If `zramSwap.memoryMax` is set alongside `memoryPercent`, nixpkgs silently uses whichever produces the smaller device size (nixpkgs issue #435031).
**Why it happens:** The zram.nix implementation uses `min()` between the two derived values.
**How to avoid:** Never set `zramSwap.memoryMax` in this module. Only `memoryPercent` is exposed as a user option; `memoryMax` is never touched.
**Warning signs:** `zramctl` shows a device smaller than `memoryPercent` implies.

### Pitfall 3: Assertion Scope

**What goes wrong:** Placing the assertion inside `lib.mkIf isBtrfs { ... }` means it never fires on LVM layout — the exact case it's meant to catch.
**Why it happens:** `lib.mkIf isBtrfs` skips the whole block when layout is LVM.
**How to avoid:** The assertion block must be a top-level `lib.mkMerge` entry, guarded only by `lib.mkIf cfg.btrfs.zram.enable` (not `lib.mkIf isBtrfs`).
**Warning signs:** `nix flake check` passes without error when `layout = "lvm"` and `zram.enable = true`.

### Pitfall 4: zramSwap.enable vs wrapper option

**What goes wrong:** Setting `zramSwap.enable = cfg.btrfs.zram.enable` at the top level (outside the BTRFS `lib.mkIf`) activates zram on LVM builds before the assertion fires.
**Why it happens:** NixOS evaluates all `config` attrsets; `zramSwap.enable = true` would be visible even on LVM.
**How to avoid:** Keep the entire `zramSwap = { ... }` block inside `lib.mkIf isBtrfs`. The assertion separately catches the misconfiguration at eval time.

## Code Examples

### Complete addition to disko.nix (diff view)

```nix
# In options.nerv.disko — add after the lvm = { ... }; block:
btrfs.zram = {
  enable = lib.mkOption {
    type        = lib.types.bool;
    default     = false;
    description = "Enable zram compressed swap (BTRFS layout only). Creates /dev/zram0 sized at memoryPercent of physical RAM.";
  };
  memoryPercent = lib.mkOption {
    type        = lib.types.ints.between 1 100;
    default     = 50;
    description = "Maximum zram swap size as a percentage of total RAM. The default (50 %) gives a 2:1 headroom for zstd-compressed pages.";
    example     = 25;
  };
};

# In config = lib.mkMerge [ ... ] — add as FIRST entry (before BTRFS branch):
(lib.mkIf cfg.btrfs.zram.enable {
  assertions = [{
    assertion = isBtrfs;
    message   = ''
      nerv: nerv.disko.btrfs.zram.enable requires
        nerv.disko.layout = "btrfs".
        The LVM layout provides disk-based swap via the swap LV.
        Disable zram or switch to the btrfs layout.
    '';
  }];
})

# Inside (lib.mkIf isBtrfs { ... }) — append after the rollback service:
zramSwap = lib.mkIf cfg.btrfs.zram.enable {
  enable        = true;
  memoryPercent = cfg.btrfs.zram.memoryPercent;
  priority      = 100;  # prefer zram over any other swap source
  # algorithm hardcoded to zstd in v3.0; use lib.mkForce to override.
  # Note: kernel.nix sets init_on_free=1. Heavy zram usage under zstd adds CPU
  # overhead (decompression on page-out) — acceptable on desktop workloads.
  algorithm     = lib.mkForce "zstd";
};
```

### Verifying zram at runtime

```bash
# After boot with zram.enable = true:
swapon --show
# Expected: /dev/zram0 listed with type=partition and non-zero size

zramctl
# Expected: /dev/zram0 ALGORITHM=zstd, DISKSIZE = (memoryPercent% of RAM)

# Priority check:
cat /proc/swaps
# Expected: /dev/zram0 priority=100
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `zramSwap.numDevices` | `zramSwap.swapDevices` | nixpkgs ~2022 | `numDevices` is a deprecated alias; use `swapDevices` directly (default: 1) |
| `lzo` default algorithm | `zstd` default | nixpkgs ~2023 | zstd compresses better with less CPU on modern hardware; already the nixpkgs default |
| `zramSwap.priority = 5` (nixpkgs default) | Set to `100` explicitly | This phase | Ensures zram is preferred over any disk swap that may be present |

**Deprecated/outdated:**
- `zramSwap.numDevices`: Deprecated alias for `swapDevices`. Never reference it.
- `zramSwap.memoryMax` + `memoryPercent` together: Produces silent size truncation (nixpkgs #435031). This module only uses `memoryPercent`.

## Open Questions

1. **`lib.mkForce` on algorithm vs plain assignment**
   - What we know: CONTEXT.md specifies `lib.mkForce "zstd"` to allow user override. The nixpkgs default is already `"zstd"`.
   - What's unclear: Whether `lib.mkForce` is needed if the default already matches, or whether it provides a meaningful escape hatch (user doing `zramSwap.algorithm = "lz4"` directly would conflict with the module setting it without `lib.mkForce`).
   - Recommendation: Keep `lib.mkForce` as specified in CONTEXT.md — it documents intent and allows override without changing this module.

2. **`zramSwap.priority` default vs 100**
   - What we know: nixpkgs default is `5`; CONTEXT.md and STATE.md both specify `100`. STATE.md pending-todos say "confirm this value."
   - What's unclear: Whether `100` or `5` is more correct given the assertion already prevents LVM+zram co-existence.
   - Recommendation: Use `100` as specified. Since LVM swap is blocked by assertion, there is no competing swap device in practice; `100` documents intent clearly and is harmless.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — NixOS module testing via `nix flake check` and `nixos-rebuild --dry-run` |
| Config file | none |
| Quick run command | `nix flake check` |
| Full suite command | `nix flake check && nixos-rebuild dry-build --flake .#host` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SWAP-01 | `nerv.disko.btrfs.zram.enable = true` causes `swapon --show` to list `/dev/zram0` | smoke (boot) | `nix flake check` (eval); `swapon --show` post-boot (manual) | ❌ Wave 0 — no test file |
| SWAP-02 | `memoryPercent = 25` sizes zram to 25% of RAM | smoke (boot) | `nix flake check` (eval); `zramctl` post-boot (manual) | ❌ Wave 0 — no test file |
| SWAP-03 | `layout = "lvm"` + `zram.enable = true` fails at eval | unit (eval) | `nix flake check` — must fail with assertion message | ❌ Wave 0 — no test file |

### Sampling Rate

- **Per task commit:** `nix flake check`
- **Per wave merge:** `nix flake check && nixos-rebuild dry-build --flake .#host`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No nixos-test VM infrastructure in this repo — SWAP-01 and SWAP-02 require manual boot verification post-deploy
- [ ] SWAP-03 can be partially validated via `nix flake check` if a test configuration with `layout = "lvm"` and `zram.enable = true` is evaluated — verify assertion fires

*(Note: This project has no test/ directory. Validation is `nix flake check` for eval correctness and manual boot verification for runtime behaviour. This is consistent with v2.0 phases.)*

## Sources

### Primary (HIGH confidence)

- nixpkgs `nixos/modules/config/zram.nix` (referenced via mynixos.com mirror) — all `zramSwap.*` option names, types, defaults
- `/home/demon/Developments/nerv.nixos/modules/system/disko.nix` — existing `cfg`, `isBtrfs`, `isLvm` bindings; `lib.mkMerge` structure; comment style
- `/home/demon/Developments/nerv.nixos/modules/system/identity.nix` — `config.assertions` pattern (project-canonical)
- `/home/demon/Developments/nerv.nixos/modules/system/impermanence.nix` — `config.assertions` with `lib.optional` (secondary example)
- `/home/demon/Developments/nerv.nixos/modules/system/kernel.nix` — confirms `init_on_free=1` is set

### Secondary (MEDIUM confidence)

- [mynixos.com zramSwap options](https://mynixos.com/options/zramSwap) — option types and defaults (mirrors nixpkgs source)
- [nixpkgs issue #435031](https://github.com/nixos/nixpkgs/issues/435031) — memoryMax+memoryPercent interaction bug; confirms avoid-memoryMax strategy

### Tertiary (LOW confidence)

- WebSearch result: `lib.mkAssert` confirmed absent from nixpkgs lib — cross-verified by project codebase (zero uses) and nixpkgs lib/asserts.nix listing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `zramSwap` options verified via nixpkgs mirror; types/defaults confirmed
- Architecture: HIGH — patterns read directly from existing project modules
- Pitfalls: HIGH — `lib.mkAssert` absence confirmed by both search and codebase grep; memoryMax bug confirmed by upstream issue

**Research date:** 2026-03-12
**Valid until:** 2026-09-12 (stable nixpkgs API; zramSwap module has not changed significantly in 3+ years)
