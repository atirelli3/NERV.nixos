# Phase 1: Flake Foundation - Research

**Researched:** 2026-03-06
**Domain:** Nix Flakes — nixosModules export, multi-flake local input, directory structure scaffolding
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Flake location**: Create a new root-level `flake.nix` — this is where `nixosModules.*` exports live. `base/flake.nix` is kept and becomes the host example flake (not removed).
- **base/flake.nix update**: Switches from importing individual module files to `inputs.nerv.url = "path:.."` and consuming `nerv.nixosModules.default` — validates the export path end-to-end.
- **Inputs**: All inputs (nixpkgs, lanzaboote, home-manager, impermanence) live in root `flake.nix` only — no duplication into `base/flake.nix`.
- **home-manager and impermanence**: Added with `inputs.nixpkgs.follows = "nixpkgs"` on both.
- **lanzaboote**: Moves to root flake (its dependency belongs to the library, not the host).
- **nixosModules exports**:
  - `nixosModules.default` = system + services + home aggregated
  - `nixosModules.system`, `nixosModules.services`, `nixosModules.home` exported individually
  - Root `modules/default.nix` imports `./system`, `./services`, and `../home` — no legacy flat module re-export
- **Stub content**: All stubs are `{ imports = []; }` — minimal and empty. `home/default.nix` has no option skeleton.
- **nixosConfigurations.nixos-base** remains in `base/flake.nix` for verification builds.

### Claude's Discretion

- Exact formatting and comment style within stub files
- Whether to add a placeholder comment in stubs noting which phase populates them

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| STRUCT-01 | Repository reorganized into `modules/system/` and `modules/services/` subdirectories with `default.nix` aggregators in each | Directory creation + stub `{ imports = []; }` pattern documented; no Nix code move happens in this phase |
| STRUCT-04 | Root `flake.nix` exports `nixosModules.default`, `nixosModules.system`, `nixosModules.services`, and `nixosModules.home` | nixosModules output schema and `import ./path` pattern confirmed; verified attribute names against home-manager and impermanence flake conventions |
| STRUCT-05 | `flake.nix` includes `home-manager` and `impermanence` as inputs with `inputs.nixpkgs.follows = "nixpkgs"` | Pattern already established for lanzaboote in existing `base/flake.nix`; confirmed impermanence uses same `inputs.nixpkgs.follows` pattern; confirmed HM module attribute is `home-manager.nixosModules.home-manager` (also aliased as `.default`) |
</phase_requirements>

---

## Summary

Phase 1 is pure structural scaffolding with no module migration. It has three deliverables: a root `flake.nix` with correct inputs and `nixosModules` exports, an updated `base/flake.nix` that consumes the root library via `inputs.nerv.url = "path:.."`, and three stub `default.nix` files (`modules/system/`, `modules/services/`, `home/`).

The critical risk is the `path:..` local flake input. Nix flakes in a git repository only include git-tracked files in the Nix store. Any new file created (root `flake.nix`, stub `default.nix` files) must be `git add`-ed before `nixos-rebuild build` or `nix flake show` will see them. Forgetting this step causes mysterious "file not found" evaluation errors that look like module bugs.

The second risk is that `nix flake check` requires `nixosModules` values to be proper NixOS module functions, not arbitrary attribute sets. Using `import ./modules` (which returns whatever `modules/default.nix` evaluates to) is safe when `default.nix` contains a valid module (`{ imports = []; }` qualifies). The `nix flake show` command is less strict and will list any attribute under `nixosModules` — so `nix flake show` can succeed while `nix flake check` fails. Use both during verification.

**Primary recommendation:** Create files, `git add` everything, then verify with `nix flake show` and `nixos-rebuild build --flake base#nixos-base` in sequence.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixpkgs | nixos-unstable | System packages + lib | Already pinned in project |
| lanzaboote | Latest tag (nix-community/lanzaboote) | Secure boot bootloader | Already used in base/flake.nix |
| home-manager | Latest (follows nixpkgs branch) | HM NixOS module | Required by STRUCT-05; consumed in Phase 5 |
| impermanence | Latest (nix-community/impermanence) | Ephemeral root persistence | Required by STRUCT-05; consumed in Phase 4 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| nix flake commands | Bundled with Nix | Evaluation + verification | `nix flake show`, `nix flake check` for phase gate |

### Alternatives Considered

None — all inputs are locked decisions.

**Installation (root flake.nix inputs block):**
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  lanzaboote = {
    url = "github:nix-community/lanzaboote";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  impermanence = {
    url = "github:nix-community/impermanence";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

---

## Architecture Patterns

### Recommended Project Structure After Phase 1

```
/                              # git root
├── flake.nix                  # NEW: library root — nixosModules exports here
├── flake.lock                 # NEW: generated by nix flake update
├── modules/
│   ├── default.nix            # NEW: { imports = [ ./system ./services ../home ]; }
│   ├── system/
│   │   └── default.nix        # NEW stub: { imports = []; }
│   ├── services/
│   │   └── default.nix        # NEW stub: { imports = []; }
│   └── *.nix                  # UNTOUCHED flat modules (moved in later phases)
├── home/
│   └── default.nix            # NEW stub: { imports = []; }
└── base/
    ├── flake.nix              # UPDATED: inputs.nerv.url = "path:.."
    ├── configuration.nix      # UNTOUCHED
    └── disko-configuration.nix# UNTOUCHED
```

### Pattern 1: nixosModules Export (root flake.nix outputs)

**What:** The `nixosModules` output attribute set exposes named NixOS modules for external flake consumption. Each value must be a valid NixOS module (a function or attribute set with `imports`/`options`/`config`).

**When to use:** When a flake provides reusable NixOS configuration for other flakes.

**Example:**
```nix
# Source: https://wiki.nixos.org/wiki/Flakes (nixosModules schema)
outputs = { self, nixpkgs, lanzaboote, home-manager, impermanence }: {
  nixosModules = {
    default  = import ./modules;           # aggregates system + services + home
    system   = import ./modules/system;
    services = import ./modules/services;
    home     = import ./home;
  };
};
```

Note: `import ./modules` resolves to `./modules/default.nix` automatically when that file exists. Both forms are equivalent.

### Pattern 2: Local Path Input (base/flake.nix)

**What:** The host example flake references the root library flake via `path:..`. This is the validated consumption path that proves `nixosModules.default` works end-to-end.

**When to use:** When one flake in a subdirectory of a git repo needs to consume another flake at the repo root.

**Example:**
```nix
# base/flake.nix after Phase 1
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nerv.url    = "path:..";
};

outputs = { self, nixpkgs, nerv, ... }: {
  nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      nerv.nixosModules.default
      ./configuration.nix
    ];
  };
};
```

The `lanzaboote` input is removed from `base/flake.nix` because `nerv.nixosModules.default` will eventually include it (via the system module). For Phase 1, the stub `modules/system/default.nix` is empty, so `lanzaboote` is temporarily unused in `base/flake.nix`. The `nixosConfigurations.nixos-base` build must still succeed via the aggregated empty stubs plus `./configuration.nix`.

### Pattern 3: Stub Aggregator Module

**What:** A minimal NixOS module that only imports sub-modules. No options, no config — just an `imports` list that will grow in later phases.

**When to use:** As a placeholder for a module directory that will be populated by future phases.

**Example:**
```nix
# modules/system/default.nix  (and modules/services/default.nix, home/default.nix)
# Populated by Phase N — stub only.
{ imports = []; }
```

```nix
# modules/default.nix — the aggregator consumed by nixosModules.default
{ imports = [ ./system ./services ../home ]; }
```

### Anti-Patterns to Avoid

- **Duplicating inputs into base/flake.nix**: `home-manager`, `impermanence`, and `lanzaboote` must not appear in `base/flake.nix` inputs. They are library dependencies, not host dependencies. Duplication causes lock file drift and confusing pin mismatches.
- **Exporting nixosModules values that are not valid modules**: Setting `nixosModules.system = ./modules/system` (a path, not an imported module) will pass `nix flake show` but fail `nix flake check`. Always use `import ./modules/system` or a function literal.
- **Creating files without git add**: New files in a git repo are invisible to Nix's flake evaluation until staged. `nix flake show` and `nixos-rebuild` will error with "file not found" or "attribute missing" rather than a clear "file not tracked" message.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Module aggregation | Custom Nix logic to discover/merge modules | `{ imports = [ ./system ./services ../home ]; }` | The module system handles merging; imports is the designed mechanism |
| Input pin management | Manually copying flake.lock entries | `inputs.X.inputs.nixpkgs.follows = "nixpkgs"` | Nix manages transitive lock coherence automatically when follows is set |
| Cross-flake consumption | Copying module files between repos | `nixosModules` flake output + `inputs.nerv.url` | Standard flake interface; enables independent versioning |

**Key insight:** The NixOS module system's `imports` list is the only correct aggregation mechanism. Do not use `lib.mkMerge`, `lib.foldl`, or custom merging — they bypass the module system's conflict detection and option priority handling.

---

## Common Pitfalls

### Pitfall 1: Untracked Files Are Invisible to Nix

**What goes wrong:** After creating `flake.nix` at the root and stub `default.nix` files, running `nix flake show` or `nixos-rebuild build` produces errors like `error: path '...' does not exist` or `attribute 'nixosModules' missing`.

**Why it happens:** Nix flakes in git repositories copy only git-tracked files into the Nix store. New files that have not been `git add`-ed are silently excluded. The error messages do not mention git tracking.

**How to avoid:** `git add` every new file immediately after creation, before running any Nix evaluation commands. The files do not need to be committed — staged is sufficient.

**Warning signs:** Error messages referencing paths that clearly exist on disk, or attributes that you can see in your editor but Nix cannot find.

### Pitfall 2: lanzaboote Import Removed from base/flake.nix Without Module Replacement

**What goes wrong:** `base/flake.nix` previously passed `lanzaboote.nixosModules.lanzaboote` and `../modules/secureboot.nix` to nixosSystem. Phase 1 removes these in favor of `nerv.nixosModules.default`. But `modules/system/default.nix` is an empty stub — it does not yet include `secureboot.nix`. If `configuration.nix` references secureboot options, the build fails with "undefined option".

**Why it happens:** `base/configuration.nix` currently has `boot.loader.systemd-boot.enable = true`. The secureboot module was imported separately in `base/flake.nix`, not in `configuration.nix`. Removing the direct import without a replacement is safe *only if* `configuration.nix` does not reference `boot.lanzaboote.*` options.

**How to avoid:** Audit `base/configuration.nix` and `base/flake.nix` before removing the lanzaboote import. Confirmed: the current `base/configuration.nix` uses `boot.loader.systemd-boot.enable = true` (not lanzaboote options). The lanzaboote and secureboot.nix imports can be removed from `base/flake.nix` without breaking the configuration.nix evaluation.

**Warning signs:** Build error mentioning `boot.lanzaboote` or `services.lanzaboote` options not found.

### Pitfall 3: home-manager nixosModules Attribute Name

**What goes wrong:** Using `home-manager.nixosModules.default` when the canonical attribute expected by downstream configuration is `home-manager.nixosModules.home-manager`.

**Why it happens:** home-manager exports both `.home-manager` (the canonical name) and `.default` (an alias). Both work. However, community documentation and examples universally reference `.home-manager`. Using `.default` in nerv's Phase 5 wiring would be non-standard.

**How to avoid:** For Phase 1, home-manager is only declared as an input — it is not consumed yet. Note for Phase 5: use `home-manager.nixosModules.home-manager` in module imports.

**Warning signs:** Not applicable in Phase 1; deferred to Phase 5.

### Pitfall 4: modules/default.nix Imports `../home` Crossing Directory

**What goes wrong:** `modules/default.nix` imports `../home` (parent-relative path). This works when the module is imported from a NixOS system evaluation rooted at the flake root — but the relative path resolution depends on where Nix resolves the import from.

**Why it happens:** NixOS module `imports` paths are resolved relative to the file containing the `imports` list. Since `modules/default.nix` is at `<root>/modules/default.nix`, `../home` correctly resolves to `<root>/home`. This is safe.

**How to avoid:** No avoidance needed — relative paths in `imports` are a standard NixOS pattern. Document the cross-directory import in a comment for future maintainers.

**Warning signs:** Would only manifest as a path resolution error during evaluation, which will be caught by the `nix flake show` gate.

### Pitfall 5: path:.. Input and the Nix Store Copy

**What goes wrong:** With `inputs.nerv.url = "path:.."`, Nix copies the referenced directory into the Nix store at evaluation time. Any file not tracked by git (and not yet staged) is excluded from this copy, causing evaluation failures in `base/`.

**Why it happens:** Same as Pitfall 1 but from the consumer side. When `base/flake.nix` uses `path:..`, the root flake's files must all be git-staged for `base/` evaluation to succeed.

**How to avoid:** `git add` all files in the root (flake.nix, modules/default.nix, modules/system/default.nix, modules/services/default.nix, home/default.nix) before running `nixos-rebuild build --flake base#nixos-base`.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Root flake.nix — Complete Phase 1 Shape

```nix
# Source: CONTEXT.md specifics + wiki.nixos.org/wiki/Flakes nixosModules schema
{
  description = "nerv — opinionated NixOS base library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, home-manager, impermanence, ... }: {
    nixosModules = {
      default  = import ./modules;
      system   = import ./modules/system;
      services = import ./modules/services;
      home     = import ./home;
    };
  };
}
```

### base/flake.nix — Phase 1 Updated Shape

```nix
# Source: CONTEXT.md specifics
{
  description = "NixOS system configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nerv.url    = "path:..";
  };

  outputs = { self, nixpkgs, nerv, ... }: {
    nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nerv.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### modules/default.nix — Aggregator

```nix
# Aggregates all nerv library modules.
# system/ populated by Phase 3, services/ by Phase 2, home/ by Phase 5.
{ imports = [ ./system ./services ../home ]; }
```

### Stub default.nix (modules/system/, modules/services/, home/)

```nix
# Stub — populated by Phase N.
{ imports = []; }
```

### Verification Commands (in order)

```bash
# 1. Stage all new files (run from repo root)
git add flake.nix modules/default.nix modules/system/default.nix \
        modules/services/default.nix home/default.nix base/flake.nix

# 2. Verify root flake exports
nix flake show

# 3. Verify base host build
nixos-rebuild build --flake ./base#nixos-base

# 4. (Optional deeper check) — verifies module structure is valid
nix flake check
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `nixpkgs.lib.nixosSystem` with flat module list | `nixosModules` output + consumer `imports` | Flakes stabilized ~2022 | Enables library flakes consumed by host flakes |
| `inputs.nixpkgs.follows` omitted (each input pins its own nixpkgs) | `inputs.X.inputs.nixpkgs.follows = "nixpkgs"` standard | Community convention by 2023 | Prevents duplicate nixpkgs in lock file, saves eval time |
| Separate flake per host with all modules inlined | Library flake (`nixosModules`) + thin host flake | Current best practice | Enables sharing modules across hosts without copying |

**Deprecated/outdated:**
- `nixosModule` (singular): Older flake schema used `nixosModule` (no `s`). The current standard is `nixosModules` (plural) with named attributes. Both are accepted by `nix flake check` but the plural form is the community standard.

---

## Open Questions

1. **lanzaboote current tag**
   - What we know: STATE.md flags this as a Phase 4 pre-condition to verify before Phase 1 pin
   - What's unclear: Whether the current `github:nix-community/lanzaboote` URL without a tag ref pins to the latest stable or latest commit
   - Recommendation: The root flake.nix input can use the bare URL for Phase 1 (same as existing base/flake.nix does now). Pinning to a specific tag is a Phase 4 concern when lanzaboote is actually activated.

2. **impermanence nixpkgs input — does it actually have one?**
   - What we know: The impermanence flake's inputs include `home-manager` which has nixpkgs as a transitive input. The impermanence flake itself does not appear to have a direct nixpkgs input.
   - What's unclear: Whether `inputs.impermanence.inputs.nixpkgs.follows = "nixpkgs"` is valid (passing follows for a non-existent direct input) or silently ignored vs causing an error.
   - Recommendation: Use `inputs.impermanence.inputs.nixpkgs.follows = "nixpkgs"` regardless — Nix silently ignores `follows` declarations for inputs that don't exist in the target flake. This is safe and matches the CONTEXT.md decision.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (NixOS — validation is `nix` CLI commands, not a test runner) |
| Config file | none |
| Quick run command | `nix flake show` |
| Full suite command | `nixos-rebuild build --flake ./base#nixos-base` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRUCT-01 | `modules/system/` and `modules/services/` directories with `default.nix` aggregators exist | smoke | `ls modules/system/default.nix modules/services/default.nix home/default.nix` | Wave 0 creates them |
| STRUCT-04 | `nix flake show` lists `nixosModules.default`, `.system`, `.services`, `.home` | integration | `nix flake show 2>&1 \| grep -E 'nixosModules\.(default\|system\|services\|home)'` | Wave 0 creates root flake.nix |
| STRUCT-05 | `flake.nix` includes `home-manager` and `impermanence` inputs with `follows` | smoke | `grep -E 'home-manager\|impermanence' flake.nix` + `grep 'nixpkgs.follows' flake.nix` | Wave 0 creates root flake.nix |
| (Phase gate) | `nixos-rebuild build --flake ./base#nixos-base` succeeds | integration | `nixos-rebuild build --flake ./base#nixos-base` | Requires all files created + git-staged |

### Sampling Rate

- **Per task commit:** `nix flake show` (fast, confirms exports exist)
- **Per wave merge:** `nixos-rebuild build --flake ./base#nixos-base`
- **Phase gate:** Both commands green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `flake.nix` — root library flake (does not exist yet)
- [ ] `modules/default.nix` — aggregator (does not exist yet)
- [ ] `modules/system/default.nix` — stub (does not exist yet)
- [ ] `modules/services/default.nix` — stub (does not exist yet)
- [ ] `home/default.nix` — stub (does not exist yet)
- [ ] `base/flake.nix` — needs update (exists, needs rewrite)

All gaps are the deliverables of this phase. No test framework installation needed — validation uses `nix` CLI which is the project's native toolchain.

---

## Sources

### Primary (HIGH confidence)

- Existing `base/flake.nix` — established `inputs.X.inputs.nixpkgs.follows` pattern
- Existing `base/configuration.nix` — confirmed no lanzaboote option references (safe to remove lanzaboote from base/flake.nix)
- `01-CONTEXT.md` — locked decisions, code shapes, integration points

### Secondary (MEDIUM confidence)

- [wiki.nixos.org/wiki/Flakes](https://wiki.nixos.org/wiki/Flakes) — nixosModules output schema and import patterns
- [github.com/nix-community/impermanence/blob/master/flake.nix](https://github.com/nix-community/impermanence/blob/master/flake.nix) — confirmed `nixosModules.impermanence` and `nixosModules.default` export names; nixpkgs is a transitive (not direct) input
- [nix-community.github.io/home-manager/](https://nix-community.github.io/home-manager/) — confirmed `home-manager.nixosModules.home-manager` and `.default` alias
- [github.com/NixOS/nix/issues/11930](https://github.com/NixOS/nix/issues/11930) — git-tracking requirement for path: inputs confirmed

### Tertiary (LOW confidence)

- WebSearch results on nixosModules function-vs-path export distinction — matches official wiki but unverified against current Nix source

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — inputs and versions match existing project patterns; confirmed against upstream flake outputs
- Architecture: HIGH — patterns derived directly from CONTEXT.md locked decisions and verified against wiki.nixos.org
- Pitfalls: HIGH for Pitfall 1 and 5 (git tracking, confirmed by NixOS issue tracker); MEDIUM for Pitfall 2 (confirmed by reading base/configuration.nix directly); MEDIUM for Pitfall 3 (HM attribute names confirmed by search, not Context7)

**Research date:** 2026-03-06
**Valid until:** 2026-09-06 (stable domain — Nix flakes schema has been stable since 2022; impermanence and HM inputs pattern stable)
