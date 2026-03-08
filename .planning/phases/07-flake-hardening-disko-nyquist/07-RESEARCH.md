# Phase 7: Flake Hardening, Disko Wiring, and Nyquist Validation - Research

**Researched:** 2026-03-08
**Domain:** NixOS flake inputs, disko wiring, Nyquist VALIDATION.md compliance
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**impermanence flake input:**
- Remove the `impermanence` input entirely from `flake.nix` inputs and the `outputs` function signature
- Rationale: `modules/system/impermanence.nix` is self-contained (uses native fileSystems + tmpfs); it explicitly does not use the upstream nixos-community/impermanence module
- The module continues to exist and function — only the unused flake input is removed

**disko wiring:**
- Add `disko` as a flake input with `inputs.nixpkgs.follows = "nixpkgs"` in `flake.nix`
- Add `disko.nixosModules.disko` to the `nixosConfigurations.nixos-base` modules list in `flake.nix`
- Import `./hosts/nixos-base/disko-configuration.nix` in the nixosConfigurations entry in `flake.nix` (not in configuration.nix)
- Remove the `fileSystems` and `swapDevices` overrides from `configuration.nix` — let disko control disk declarations
- Before removing overrides: audit `disko-configuration.nix` and ensure security-relevant mount options are present (fmask=0077, dmask=0077 on /boot, correct ext4 options on /)

**secureboot/impermanence in configuration.nix:**
- Add `nerv.secureboot.enable = false` and `nerv.impermanence.enable = false` explicitly in `configuration.nix`
- Placement: grouped with other disabled `nerv.*` service options (near the end with the existing `nerv.audio.enable = false` etc.)
- Each declaration gets a brief inline comment pointing to the relevant module and explaining what enabling it requires
  - e.g. `# enable in modules/system/secureboot.nix — requires TPM2 + UEFI firmware`
  - e.g. `# enable in modules/system/impermanence.nix — mounts /tmp, /var/tmp as tmpfs`
- Grouped under a `# Disabled features — explicitly declared to make activation path visible to operators` comment header

**Nyquist validation approach:**
- Use hybrid approach: run what is runnable in the dev environment (nix flake show, grep-based commands), mark remaining checks based on code review for tasks that require a real NixOS machine
- Update ALL sections of each VALIDATION.md — Wave 0 requirements checklist, task status rows (pending → green or red), Validation Sign-Off checkboxes, and frontmatter (`nyquist_compliant: true`)
- Add missing automated test commands where gaps exist (tasks with no `Automated Command` entry)
- Scope: strictly the 6 existing VALIDATION.md files (phases 1–6) — no new test infrastructure

### Claude's Discretion
- Exact pinned tag/URL for the disko flake input (look up nix-community/disko current stable)
- Order of modules in nixosConfigurations.nixos-base (keep existing order, append disko + disko-configuration.nix)
- Exact syntax for importing disko-configuration.nix as a module in nixosConfigurations

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 7 is pure tech debt closure across three distinct areas: (1) removing the unused `impermanence` flake input, (2) properly wiring `disko` as a flake input and module, and (3) retroactively marking all six VALIDATION.md files as `nyquist_compliant: true` after filling their gaps. No new v1.0 requirements are addressed.

The current `flake.nix` already uses the exact input pattern needed for disko (`url` + `inputs.nixpkgs.follows = "nixpkgs"`) — the addition is mechanical. The `disko-configuration.nix` already exists and is largely correct but needs a mount option audit before the `lib.mkForce` overrides in `configuration.nix` can be dropped. The VALIDATION.md files are all in `draft` / `nyquist_compliant: false` status and are structurally correct — they just need status rows updated and sign-off checkboxes ticked.

**Primary recommendation:** Implement the three areas as three separate plans (flake edits, configuration.nix cleanup, VALIDATION.md batch update) to keep diffs atomic and reviewable. The disko wiring is the only area with evaluation risk; validate with `nix flake show` after each flake change.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nix-community/disko | v1.13.0 (2026-01-20) | Declarative disk partitioning NixOS module | The canonical flake-native disk layout tool for NixOS; nixosModules.disko generates fileSystems from declarative config |
| nix-community/impermanence | (removed) | Ephemeral root persistence | NOT used — project's impermanence.nix is self-contained using native NixOS fileSystems; flake input is dead weight |

### Supporting

No additional libraries needed. All tooling (`nix flake show`, `nix-instantiate --parse`, `nixos-rebuild build`) is already present in the project's native validation stack.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Removing impermanence input | Commenting it out | Decided against — dead inputs create lock file bloat and operator confusion |
| Pinned disko tag | `github:nix-community/disko` (no tag) | Tag pin provides reproducibility; project uses nixos-unstable nixpkgs so locking disko prevents surprise breakage |

**Installation:**
```bash
# No npm/pip install — all changes are flake.nix edits
# After editing flake.nix:
nix flake update disko   # fetches disko and adds to flake.lock
nix flake show           # verifies outputs are valid
```

---

## Architecture Patterns

### Recommended Project Structure (after Phase 7)

```
flake.nix                                      # disko input added; impermanence removed
hosts/nixos-base/
  configuration.nix                            # fileSystems/swapDevices removed; disabled features added
  disko-configuration.nix                      # audited mount options; no structural change
.planning/phases/{01..06}-*/
  {01..06}-VALIDATION.md                       # nyquist_compliant: true; all rows updated
```

### Pattern 1: Disko Flake Input (the project's existing pattern)

**What:** Add `disko` to `inputs` with `inputs.nixpkgs.follows`, destructure in `outputs`, add module to nixosConfigurations.

**When to use:** Always — consistent with how lanzaboote and home-manager are wired.

**Example:**
```nix
# Source: existing flake.nix + nix-community/disko README pattern
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

  # Declarative disk layout — provides disko.nixosModules.disko
  disko = {
    url = "github:nix-community/disko/v1.13.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};

outputs = { self, nixpkgs, lanzaboote, home-manager, disko, ... }: {
  nixosConfigurations.nixos-base = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      lanzaboote.nixosModules.lanzaboote
      home-manager.nixosModules.home-manager
      self.nixosModules.default
      ./hosts/nixos-base/configuration.nix
      disko.nixosModules.disko               # generates fileSystems from disko.devices
      ./hosts/nixos-base/disko-configuration.nix
    ];
  };
};
```

### Pattern 2: disko-configuration.nix as a plain module in nixosConfigurations

**What:** Import `./hosts/nixos-base/disko-configuration.nix` directly in the modules list (not via configuration.nix imports). This keeps host-machine-specific disk layout out of the shared modules tree.

**When to use:** When the disko config is a host-specific file, not a reusable module.

**Example:**
```nix
# Correct: in nixosConfigurations modules list
modules = [
  disko.nixosModules.disko
  ./hosts/nixos-base/disko-configuration.nix   # sets disko.devices attrset
  ./hosts/nixos-base/configuration.nix
];

# Wrong: in configuration.nix imports = [ ./disko-configuration.nix ]
# This works but conflates host config with disk layout declaration
```

### Pattern 3: Explicit disabled-feature declarations in configuration.nix

**What:** Declare `nerv.*.enable = false` explicitly for every feature that has a NixOS module but is intentionally off, grouped under a descriptive comment.

**When to use:** Any time an optional module exists (`secureboot.nix`, `impermanence.nix`) but is not activated on the current host. Makes the "off" state as visible as the "on" state.

**Example:**
```nix
# Disabled features — explicitly declared to make activation path visible to operators
nerv.audio.enable     = false; # enable when on target NixOS machine with audio hardware
nerv.bluetooth.enable = false; # enable when on target NixOS machine with bluetooth adapter
nerv.printing.enable  = false;
nerv.secureboot.enable    = false; # enable in modules/system/secureboot.nix — requires TPM2 + UEFI firmware
nerv.impermanence.enable  = false; # enable in modules/system/impermanence.nix — mounts /tmp, /var/tmp as tmpfs
```

### Pattern 4: Nyquist VALIDATION.md compliant sign-off

**What:** A VALIDATION.md is `nyquist_compliant: true` when: (1) all Wave 0 items are checked, (2) all task status rows are `green` or `red` (not `pending`), (3) all sign-off checkboxes are ticked, (4) no task row has an empty Automated Command unless it is Manual-Only.

**Update sequence per file:**
1. Wave 0 Requirements: tick all checkboxes (files exist — phases are complete)
2. Per-Task Verification Map: change `pending` to `green` for tasks that were implemented; add automated command where missing
3. Validation Sign-Off: tick all checkboxes
4. Frontmatter: change `nyquist_compliant: false` to `nyquist_compliant: true` and `status: draft` to `status: complete`

### Anti-Patterns to Avoid

- **Removing the disko module but keeping the disko-configuration.nix import:** `disko.devices` attrset is only consumed when `disko.nixosModules.disko` is in the modules list. Without the module, the attrset is silently ignored and fileSystems reverts to whatever nixos-base generates.
- **Importing disko-configuration.nix inside configuration.nix:** Works but muddies separation of concerns. The decision is to keep it in the nixosConfigurations modules list.
- **Leaving `lib.mkForce` overrides in configuration.nix after wiring disko:** The overrides suppress disko-generated fileSystems. Once disko is wired and disko-configuration.nix is in the modules list, the `lib.mkForce` blocks must be removed — otherwise the security-relevant mount options in disko-configuration.nix (umask=0077 on /boot) will be overridden.
- **Marking VALIDATION.md as `nyquist_compliant: true` without auditing sign-off:** The six checkboxes in Validation Sign-Off must all be ticked. Setting the frontmatter flag without reviewing each item defeats the compliance contract.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| fileSystems declarations for disko layout | lib.mkForce overrides in configuration.nix | disko.nixosModules.disko + disko-configuration.nix | Hand-rolled overrides fight disko; disko module generates correct NixOS fileSystems attrset including swap |
| Tracking disko in flake.lock | Manually updating flake.lock | `nix flake update disko` | Nix manages lock entries; manual edits break integrity checks |

**Key insight:** The `lib.mkForce` overrides in `configuration.nix` are explicitly there as a workaround for the fact that disko was not wired as a module. After wiring, they become actively harmful — remove them.

---

## Common Pitfalls

### Pitfall 1: Mount option gap — disko uses `umask=0077` but configuration.nix used `fmask=0077 dmask=0077`

**What goes wrong:** The current `disko-configuration.nix` ESP entry uses `mountOptions = [ "umask=0077" ]` (line 29). The `configuration.nix` `lib.mkForce` override uses `[ "fmask=0077" "dmask=0077" ]`. These are not identical. `umask=0077` applies to both files (fmask) and directories (dmask) on FAT32 but is a single option vs two separate ones. The behavior is equivalent on vfat but the OPTIONS LIST IS DIFFERENT.

**Why it happens:** The disko-configuration.nix was written with `umask=0077` and the configuration.nix override was added separately with the more explicit pair.

**How to avoid:** Audit the CONTEXT.md decision: "ensure security-relevant mount options are present (fmask=0077, dmask=0077 on /boot)". Update disko-configuration.nix ESP `mountOptions` to `[ "fmask=0077" "dmask=0077" ]` before removing the `lib.mkForce` override. This makes the effective options identical to the current state.

**Warning signs:** After removing the override, run `mount | grep boot` on a real machine to confirm options are applied.

### Pitfall 2: impermanence inputs attribute still in `outputs` function signature after removal

**What goes wrong:** Removing `impermanence` from `inputs` but forgetting to remove it from `outputs = { self, nixpkgs, lanzaboote, home-manager, impermanence, ... }:` causes a Nix evaluation error: attribute `impermanence` is not found in the destructured set.

**Why it happens:** `flake.nix` has two places where inputs are referenced: the `inputs` attrset and the `outputs` function signature.

**How to avoid:** Remove `impermanence` from BOTH locations. Verify with `nix flake show` immediately after.

**Warning signs:** `nix flake show` fails with `error: attribute 'impermanence' missing`.

### Pitfall 3: disko generates fileSystems that conflict with LUKS/LVM boot setup

**What goes wrong:** disko's NixOS module generates `boot.initrd.luks.devices` entries and `fileSystems` based on its device tree. If the generated entries conflict with entries in `configuration.nix` or `boot.nix`, Nix module merging may error or produce unexpected results.

**Why it happens:** The project's `boot.nix` already declares `boot.initrd.luks.devices.cryptroot`. Disko may generate its own `luks.devices` entry for the same LUKS container.

**How to avoid:** After wiring disko, build with `nixos-rebuild build --flake .#nixos-base` and inspect any merge conflicts. The `luks.name = "cryptroot"` in disko-configuration.nix (line 37) must match the name used in boot.nix. No changes needed if they already match.

**Warning signs:** Build error mentioning `boot.initrd.luks.devices` attribute conflict.

### Pitfall 4: VALIDATION.md task status rows left as `pending` when tasks are complete

**What goes wrong:** Marking `nyquist_compliant: true` in frontmatter but leaving task rows as `pending` is self-contradicting. The file fails its own compliance criteria.

**Why it happens:** Updating 6 files with 40+ task rows is mechanical work that is easy to do incompletely.

**How to avoid:** For each VALIDATION.md, update ALL status cells from `pending` to a terminal state. For phases 1–6 which are all implemented: mark as `green` for tasks that evaluate cleanly, `red` with note for tasks that require live NixOS hardware (which cannot be run in dev environment).

**Warning signs:** Any `pending` in the Status column while `nyquist_compliant: true` is set.

### Pitfall 5: Phase 1 VALIDATION.md still references `./base#nixos-base` build path

**What goes wrong:** Phase 1 VALIDATION.md (line 24) has `nixos-rebuild build --flake ./base#nixos-base` as the full suite command. The project moved to root flake `#nixos-base` in Phase 1 itself. The VALIDATION.md never got updated.

**Why it happens:** The VALIDATION.md was written before the path decision was finalized.

**How to avoid:** When updating Phase 1 VALIDATION.md, correct the full suite command to `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` (matching the path pattern used in phases 3 and 4).

### Pitfall 6: Phase 5 Wave 0 items reference tasks already completed

**What goes wrong:** Phase 5 VALIDATION.md Wave 0 lists `home/default.nix`, `flake.nix`, and `configuration.nix` changes as pending. These were all completed during phase execution. Leaving them unchecked incorrectly signals the phase is not ready.

**How to avoid:** Tick all Wave 0 checkboxes for phases 1–6 — the phases are complete.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### Disko flake input (canonical pattern)

```nix
# Source: nix-community/disko README + project's existing input pattern
disko = {
  url = "github:nix-community/disko/v1.13.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### Outputs function signature after impermanence removal + disko addition

```nix
# Source: existing flake.nix adapted
outputs = { self, nixpkgs, lanzaboote, home-manager, disko, ... }:
```

### nixosConfigurations modules list after wiring

```nix
# Source: nix-community/disko quickstart + project convention
modules = [
  lanzaboote.nixosModules.lanzaboote
  home-manager.nixosModules.home-manager
  self.nixosModules.default
  ./hosts/nixos-base/configuration.nix
  disko.nixosModules.disko
  ./hosts/nixos-base/disko-configuration.nix
];
```

### disko-configuration.nix ESP mount options correction

```nix
# Current (line 29 of disko-configuration.nix):
mountOptions = [ "umask=0077" ];

# After audit (to match prior configuration.nix override):
mountOptions = [ "fmask=0077" "dmask=0077" ];
```

### configuration.nix after fileSystems removal

```nix
# REMOVE these blocks:
# fileSystems = { "/boot" = lib.mkForce { ... }; "/" = lib.mkForce { ... }; };
# swapDevices = [{ device = "/dev/disk/by-label/NIXSWAP"; }];

# REMOVE from header comment:
# Note: fileSystems use lib.mkForce to override Disko-generated mounts.

# UPDATE header comment to reflect new reality:
# Note: disko.nixosModules.disko + disko-configuration.nix in flake.nix
#       manage all fileSystems and swapDevices declarations.
```

### VALIDATION.md frontmatter update pattern

```yaml
# Before:
status: draft
nyquist_compliant: false
wave_0_complete: false

# After:
status: complete
nyquist_compliant: true
wave_0_complete: true
```

### VALIDATION.md task row status update pattern

```markdown
# Before:
| 6-01-01 | 01 | 1 | DOCS-01 | parse | `nix-instantiate --parse modules/services/openssh.nix` | ✅ | ⬜ pending |

# After (phase implemented, file exists, command runnable):
| 6-01-01 | 01 | 1 | DOCS-01 | parse | `nix-instantiate --parse modules/services/openssh.nix` | ✅ | ✅ green |
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| fileSystems in configuration.nix with lib.mkForce | disko.nixosModules.disko generates fileSystems | Phase 7 (this phase) | Removes override anti-pattern; disk layout is single source of truth |
| impermanence as unused flake input | Removed | Phase 7 (this phase) | Cleaner flake.lock; removes misleading dependency signal |
| VALIDATION.md status draft/pending | nyquist_compliant: true | Phase 7 (this phase) | Closes audit gap B (missing validation) |

**Deprecated/outdated:**
- `impermanence` flake input: present since Phase 1, now removed — `modules/system/impermanence.nix` is self-contained
- `lib.mkForce` fileSystems overrides in `configuration.nix`: workaround for missing disko module, removed when disko is wired

---

## Open Questions

1. **Whether `disko.nixosModules.disko` generates `boot.initrd.luks.devices` entries that conflict with boot.nix**
   - What we know: boot.nix declares `boot.initrd.luks.devices.cryptroot`; disko-configuration.nix has a `luks` content type with `name = "cryptroot"`
   - What's unclear: Whether disko's NixOS module generates `luks.devices` entries or only `fileSystems` entries
   - Recommendation: Build with `nixos-rebuild build --flake .#nixos-base` immediately after wiring disko; if conflict, add `disko.enableConfig = false` or remove disko's luks generation (see disko options)

2. **Whether the Phase 1 VALIDATION.md task 1-01-04 was verified with `./base#nixos-base` or `.#nixos-base`**
   - What we know: Task command references `./base#nixos-base`; project moved to root flake during Phase 1
   - What's unclear: Which path was actually used during phase execution
   - Recommendation: Update to `.#nixos-base` (or absolute path) when marking complete — the historic path is wrong regardless

---

## Validation Architecture

> nyquist_validation is true in .planning/config.json — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | nix CLI (nix flake show, nix-instantiate --parse, nixos-rebuild build) — no traditional test framework |
| Config file | flake.nix |
| Quick run command | `nix flake show /home/demon/Developments/test-nerv.nixos` |
| Full suite command | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |

### Phase Requirements → Test Map

This phase has no new v1.0 requirements (tech debt closure only). The test map covers the four deliverables:

| Deliverable | Behavior | Test Type | Automated Command |
|-------------|----------|-----------|-------------------|
| impermanence input removed | flake.nix evaluates without impermanence in inputs | smoke | `nix flake show /home/demon/Developments/test-nerv.nixos` |
| disko wired | nixosConfigurations.nixos-base includes disko module | smoke | `nix flake show /home/demon/Developments/test-nerv.nixos` |
| fileSystems removed from configuration.nix | Build succeeds with disko providing fileSystems | integration | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |
| disabled feature declarations added | nerv.secureboot.enable + nerv.impermanence.enable present | smoke | `grep -E 'nerv\.(secureboot\|impermanence)\.enable' /home/demon/Developments/test-nerv.nixos/hosts/nixos-base/configuration.nix` |
| VALIDATION.md updated (all 6) | All 6 files have nyquist_compliant: true | smoke | `grep 'nyquist_compliant: true' /home/demon/Developments/test-nerv.nixos/.planning/phases/*/*.md \| wc -l` (expect 6) |

### Sampling Rate

- **Per task commit:** `nix flake show /home/demon/Developments/test-nerv.nixos`
- **Per wave merge:** `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — existing test infrastructure (`nix flake show`, `nixos-rebuild build`, `nix-instantiate --parse`, `grep`) covers all phase deliverables. No test files need to be created.

---

## Current Code State (Reference for Planner)

### flake.nix — what exists now

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  lanzaboote = { url = "github:nix-community/lanzaboote"; inputs.nixpkgs.follows = "nixpkgs"; };
  home-manager = { url = "github:nix-community/home-manager"; inputs.nixpkgs.follows = "nixpkgs"; };
  impermanence = { url = "github:nix-community/impermanence"; inputs.nixpkgs.follows = "nixpkgs"; };
  # MISSING: disko
};
outputs = { self, nixpkgs, lanzaboote, home-manager, impermanence, ... }:
# NOTE: impermanence in destructured args but NEVER USED in outputs body
```

### configuration.nix — what must be removed + added

**Remove:**
- Lines 9 (`Note: fileSystems use lib.mkForce ...`)
- Lines 21-34 (entire `# lib.mkForce overrides...` comment + `fileSystems` attrset)
- Line 34 (`swapDevices = [...]`)

**Add (near nerv.audio.enable = false group):**
```nix
# Disabled features — explicitly declared to make activation path visible to operators
nerv.secureboot.enable   = false; # enable in modules/system/secureboot.nix — requires TPM2 + UEFI firmware
nerv.impermanence.enable = false; # enable in modules/system/impermanence.nix — mounts /tmp, /var/tmp as tmpfs
```

### disko-configuration.nix — what needs auditing

Current ESP mountOptions: `[ "umask=0077" ]` (line 29)
Required: `[ "fmask=0077" "dmask=0077" ]` to match the security intent of the removed override.

Root volume: no explicit mountOptions — this matches the removed override (which had none beyond device/fsType).

### VALIDATION.md status across all 6 phases

| Phase | File | nyquist_compliant | wave_0_complete | Status field | Task rows |
|-------|------|------------------|-----------------|--------------|-----------|
| 1 | 01-VALIDATION.md | false | false | draft | all pending |
| 2 | 02-VALIDATION.md | false | false | draft | all pending |
| 3 | 03-VALIDATION.md | false | false | draft | all pending |
| 4 | 04-VALIDATION.md | false | false | draft | all pending |
| 5 | 05-VALIDATION.md | false | false | draft | all pending |
| 6 | 06-VALIDATION.md | false | false | draft | all pending |

All 6 require: frontmatter update, Wave 0 checkbox tick, task row status update, sign-off checkbox tick.

**Phase 1 special case:** Full suite command references stale path `./base#nixos-base` — must be corrected.

**Phase 5 special case:** Wave 0 lists `home/default.nix`, `flake.nix`, `configuration.nix` as pending creation — all were created during phase execution; tick checkboxes.

---

## Sources

### Primary (HIGH confidence)
- GitHub API `api.github.com/repos/nix-community/disko/releases/latest` — confirms v1.13.0 released 2026-01-20
- Existing `flake.nix` in repository — confirms current input pattern for lanzaboote/home-manager
- Existing `hosts/nixos-base/disko-configuration.nix` — confirms file exists and current mount options
- Existing `hosts/nixos-base/configuration.nix` — confirms exact lines to remove
- All 6 VALIDATION.md files — confirms current status fields and gaps

### Secondary (MEDIUM confidence)
- WebSearch result: `disko.nixosModules.disko` is the canonical module attribute name — confirmed by multiple NixOS community examples (nixos.asia, mich-murphy.com)
- WebSearch result: `inputs.nixpkgs.follows = "nixpkgs"` is the correct `follows` attribute name for disko — consistent across all examples found

### Tertiary (LOW confidence)
- Whether disko v1.13.0 generates `boot.initrd.luks.devices` entries (open question above) — could not verify from search results; needs build-time validation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — disko v1.13.0 confirmed from GitHub API; module attribute confirmed by multiple community examples
- Architecture: HIGH — based on reading actual project files; all patterns are derived from existing code
- Pitfalls: HIGH — mount option discrepancy (umask vs fmask/dmask) identified from reading actual file content at lines 29-31
- VALIDATION.md gaps: HIGH — all 6 files read directly; gaps catalogued from file content

**Research date:** 2026-03-08
**Valid until:** 2026-04-08 (stable domain; disko releases infrequently)
