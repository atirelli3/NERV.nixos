# Phase 13: Audit Gap Closure — Research

**Researched:** 2026-03-12
**Domain:** NixOS flake wiring, Nix module header conventions, BTRFS install documentation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Add a `server` let-binding in the `let` block, immediately after the `host` let-binding
- `server` contains: `nerv.disko.layout = "lvm"` and `nerv.impermanence.mode = "full"` (plus `nerv.impermanence.enable = true`)
- All other server options left at defaults (openssh, secureboot, audio, bluetooth, printing stay at defaults)
- `nixosConfigurations.server` mirrors `nixosConfigurations.host` exactly: same module list (`lanzaboote`, `home-manager`, `impermanence`, `disko`, `self.nixosModules.default`, the `server` let-binding, `./hosts/configuration.nix`)
- `nerv.secureboot.enable` defaults to `false` so lanzaboote is imported but Secure Boot is off — no special handling needed
- `disko.nix` header: `# Profiles : host layout=btrfs | server layout=lvm`
- `impermanence.nix` header: `# Profiles : host mode=btrfs | server mode=full`
- `boot.nix` header: `# Profiles : host | server` (boot.nix is layout-agnostic — no values to show)
- Comment goes as an additional line in the existing header block (after the current description line)
- `@root-blank` snapshot inserted as a standalone numbered step between current step 6 (disko) and current step 7 (copy repo) — becomes new step 7; subsequent steps shift by +1 (old 7→8, 8→9, ... 13→14)
- Snapshot step includes inline comment: `# Required: @root-blank is the clean-root template — initrd deletes @ and restores from this on every boot.`
- Command: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`
- Change stale comment on `modules/system/default.nix` line 13 to: `# declarative disk layout (btrfs/lvm) with layout-conditional initrd services`

### Claude's Discretion

- Exact alignment/padding of the `server` let-binding (follow existing aligned `=` style from `host`)
- Whether to add a `nerv.openssh.enable = true` to `server` let-binding for explicitness (or leave at default)
- Exact placement of the `# Profiles :` line within each header block (after description, before blank line)

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISKO-02 | User can set `nerv.disko.layout = "lvm"` to get the existing GPT/LUKS/LVM layout | LVM branch already fully implemented in disko.nix; gap is the missing `nixosConfigurations.server` flake output that exercises it |
| PROF-02 | `serverProfile` declares `nerv.disko.layout = "lvm"` explicitly | `server` let-binding in flake.nix; mirrors `host` binding structure exactly |
| BOOT-02 | When `nerv.disko.layout = "btrfs"`, rollback unit deletes `@` and snapshots `@root-blank → @` | Already implemented in disko.nix; gap is the README doc step that creates `@root-blank` during install |
| PROF-04 | Install procedure documents the required post-disko manual step: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank` | README Section A step insertion between current steps 6 and 7 |
| PROF-03 | Section-header comments on `disko.nix`, `boot.nix`, and `impermanence.nix` updated to reflect new options and behavior | `# Profiles :` cross-reference lines added to each header's description line block |
</phase_requirements>

---

## Summary

Phase 13 is a pure wiring-and-documentation closure phase. All functional implementation is already complete in prior phases. Four concrete gaps remain from the v2.0 milestone audit: (1) `nixosConfigurations.server` is absent from `flake.nix` — the `host` output exists but there is no parallel `server` output referencing the `lvm` layout, making `nix eval .#nixosConfigurations.server.*` fail; (2) README Section A (BTRFS install) is missing the `@root-blank` snapshot step, which means any operator following the walkthrough will end up with a first boot where the rollback service has no template to restore from; (3) three module headers (`disko.nix`, `boot.nix`, `impermanence.nix`) lack `# Profiles :` cross-reference lines; (4) the comment on `modules/system/default.nix` line 13 is stale (refers to impermanence mode instead of layout-conditional initrd).

All four changes are mechanical. No new options, no module logic changes, no new flake inputs. The research task is therefore primarily a precise source-code audit rather than a technology investigation: understand the exact current state of each target file so the planner can write minimal, correct diffs.

**Primary recommendation:** Read every target file before writing any task action. The changes are small but must be exact — wrong indentation in a Nix attrset or a renumbered README step with an off-by-one error produces a broken artifact.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nixpkgs | unstable | NixOS module system | Project's pinned input |
| disko | v1.13.0 | Declarative disk layout | Project's pinned input |
| lanzaboote | current | Secure Boot | Project's pinned input |
| home-manager | current | Home Manager NixOS module | Project's pinned input |
| impermanence | current | environment.persistence | Project's pinned input |

All inputs are already declared in `flake.nix`. No new inputs required for this phase.

### Supporting

None — this phase makes no changes to module logic, options, or dependencies.

### Alternatives Considered

None — locked decisions specify exact approach.

**Installation:** No new packages. No `npm install` or equivalent.

---

## Architecture Patterns

### flake.nix let-binding pattern

The existing `host` let-binding is the exact template. The `server` let-binding must:

1. Appear immediately after the closing `};` of the `host` binding
2. Use the same aligned-`=` padding style (column-align values to the same column as `host`)
3. Include only the three options that differ from defaults: `nerv.disko.layout`, `nerv.impermanence.enable`, `nerv.impermanence.mode`

Current `host` binding occupies lines 34–62 of `flake.nix`. The `server` binding inserts after line 62, before the `in {` on line 64.

### nixosConfigurations.server placement

The `nixosConfigurations.server` output block must appear immediately after the `nixosConfigurations.host` block (after its closing `};` on line 87). It is a verbatim copy of the `host` block with two substitutions: `host` → `server` in the `modules` list entry and in the comment.

The module list order must be identical:
```
lanzaboote.nixosModules.lanzaboote
home-manager.nixosModules.home-manager
impermanence.nixosModules.impermanence
disko.nixosModules.disko
self.nixosModules.default
server              # ← was: host
./hosts/configuration.nix
```

### Module header comment pattern

Current three-file headers follow this structure:

**disko.nix** (line 1–3):
```
# modules/system/disko.nix
#
# Declarative disk layout and layout-conditional initrd config. btrfs (desktop) or lvm (server). No default — must be set explicitly.
```

**boot.nix** (line 1–3):
```
# modules/system/boot.nix
#
# Layout-agnostic initrd and bootloader (systemd-boot + EFI). Layout-specific initrd config lives in disko.nix.
```

**impermanence.nix** (line 1–3):
```
# modules/system/impermanence.nix
#
# Selective persistence via environment.persistence bind-mounts. btrfs mode for desktop; full mode for server.
```

The `# Profiles :` line inserts as a new line 4 in each file (after the description line, before the blank line that separates the header from the function args). Each file currently has NO line 4 — line 4 is `{ config, lib, pkgs, ... }:` or `{ pkgs, ... }:`. The insertion adds a new line between the description comment and the args line, making the header 4 lines instead of 3.

Concretely:
- **disko.nix**: new line 4 = `# Profiles : host layout=btrfs | server layout=lvm`
- **impermanence.nix**: new line 4 = `# Profiles : host mode=btrfs | server mode=full`
- **boot.nix**: new line 4 = `# Profiles : host | server`

The blank line separating header from function args must be preserved — insert after the description line, keeping the blank line before `{ config, ... }:`.

Wait — looking at the actual files again: the header is 3 lines (filename, blank `#`, description), then a blank line, then function args. There is NO blank line in the header itself between `#` and the description. The blank line after the description IS the separator to function args.

Actual structure of disko.nix lines 1–5:
```
1: # modules/system/disko.nix
2: #
3: # Declarative disk layout ...
4: (blank)
5: { config, lib, pkgs, ... }:
```

The `# Profiles :` line inserts after line 3 and before line 4 (blank). Result:
```
1: # modules/system/disko.nix
2: #
3: # Declarative disk layout ...
4: # Profiles : host layout=btrfs | server layout=lvm
5: (blank)
6: { config, lib, pkgs, ... }:
```

boot.nix is the same structure — 3-line header, blank line, then `{ pkgs, ... }:`.

### modules/system/default.nix line 13 comment

Current line 13:
```nix
    ./disko.nix         # declarative disk layout — conditional LVM LVs based on impermanence mode
```

Target line 13:
```nix
    ./disko.nix         # declarative disk layout (btrfs/lvm) with layout-conditional initrd services
```

The stale reference to "impermanence mode" is wrong — disko.nix now branches on `nerv.disko.layout`, not impermanence mode. The new comment accurately reflects what the module does.

### README Section A step renumbering

Current step sequence in Section A (BTRFS):
```
1. Boot ISO
2. Clone repo
3. Fill host config
4. (Optional) Enable Secure Boot
5. Set LUKS password
6. Provision disk (disko)
7. Copy repo to /mnt
8. Generate hardware config
9. sbctl keys (if Secure Boot)
10. Stage + install
11. Set user password
12. Copy config to /persist
13. Reboot
```

New step sequence after inserting `@root-blank` snapshot between old 6 and old 7:
```
1-6: unchanged
7. [NEW] btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
8. (was 7) Copy repo to /mnt
9. (was 8) Generate hardware config
10. (was 9) sbctl keys
11. (was 10) Stage + install
12. (was 11) Set user password
13. (was 12) Copy config to /persist
14. (was 13) Reboot
```

### Anti-Patterns to Avoid

- **Renaming existing modules or options:** This phase is wiring only — no renames.
- **Adding openssh.enable to server profile:** It defaults to false. The discretion call is to leave defaults implicit unless there's a documentation reason to make it explicit. The `host` binding already shows the pattern of only listing non-default values as active lines — follow the same for `server`.
- **Modifying Section B (LVM walkthrough):** CONTEXT.md and STATE.md are explicit that Section B must not be modified in this phase (decision from Phase 12).
- **Touching `hosts/configuration.nix`:** That file sets profile-specific values; the phase only changes `flake.nix`, three module headers, `modules/system/default.nix`, and `README.md`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Flake output validation | Manual eval testing | `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` | Verifies attribute path resolves without full build |

**Key insight:** There is nothing novel to build here. Every pattern (let-binding structure, nixosConfigurations shape, header comment style, README step format) already exists in the codebase as a working example. The task is replication, not invention.

---

## Common Pitfalls

### Pitfall 1: Misaligned `=` in server let-binding

**What goes wrong:** The server binding uses different column alignment than host, producing inconsistent visual style.

**Why it happens:** The `host` binding has precisely aligned `=` signs — `nerv.disko.layout         = "btrfs"` (many spaces). The server binding is shorter: `nerv.disko.layout = "lvm"` without padding would look inconsistent.

**How to avoid:** Count the column of `=` in the host block (column ~35) and match exactly. The three server lines are:
```nix
      nerv.disko.layout         = "lvm";   # same column as host
      nerv.impermanence.enable  = true;    # same column
      nerv.impermanence.mode    = "full";  # same column
```

**Warning signs:** The server block looks visually compressed compared to the host block.

### Pitfall 2: Wrong step numbers in README

**What goes wrong:** New step 7 inserts correctly but subsequent step numbers in the comments are not all updated.

**Why it happens:** Steps 7–13 each have a `# N.` comment prefix. Missing any one of the 7 edits leaves a duplicate or skipped number.

**How to avoid:** Update every step comment from 7 through 13 → 8 through 14 in one pass. The BTRFS section has exactly 13 steps; after insertion it has 14.

**Warning signs:** Two steps share the same number, or the final reboot is numbered 13 instead of 14.

### Pitfall 3: Inserting `# Profiles :` after the blank separator line

**What goes wrong:** The `# Profiles :` line appears after the blank line, making it look detached from the header block and before the function args.

**Why it happens:** The blank line after the description is easy to mistake as part of the header.

**How to avoid:** The `# Profiles :` line belongs inside the comment block (lines starting with `#`), immediately after the description line and before the blank separator. The blank separator line stays between the comment block and the function args `{ ... }:`.

**Warning signs:** The file has `# Profiles :` on a line immediately before `{ config, lib, pkgs, ... }:` with no blank line between them — or worse, no blank line at all.

### Pitfall 4: Forgetting the `-r` flag in the snapshot command

**What goes wrong:** `btrfs subvolume snapshot /mnt/@ /mnt/@root-blank` (without `-r`) creates a read-write snapshot. The rollback service expects a read-only snapshot as the baseline.

**Why it happens:** The `-r` flag is easy to omit.

**How to avoid:** The command in CONTEXT.md is explicit: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank`. Copy verbatim.

### Pitfall 5: `nix flake check` failing on server configuration

**What goes wrong:** `nixosConfigurations.server` fails evaluation because `hosts/configuration.nix` has `nerv.disko.layout = "PLACEHOLDER"` or similar.

**Why it happens:** `hosts/configuration.nix` is shared between host and server. If it sets a layout explicitly, the server profile module list also sources it, potentially conflicting.

**How to avoid:** Read `hosts/configuration.nix` before writing the task. The decision from Phase 9 says: `nerv.disko.layout = PLACEHOLDER` intentionally invalid — forces operator to set btrfs or lvm before building. The `server` let-binding in flake.nix sets `nerv.disko.layout = "lvm"` which overrides the PLACEHOLDER via NixOS merge. This is the correct behavior — the let-binding wins over the placeholder. Verify `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` returns `"lvm"`.

---

## Code Examples

Verified patterns from existing codebase:

### server let-binding (modeled on host, lines 34–62 of flake.nix)

```nix
    # Headless server configuration.
    # Defaults applied: LVM layout, full tmpfs impermanence.
    server = {
      nerv.disko.layout         = "lvm";   # "btrfs" for desktop/laptop | "lvm" for server
      nerv.impermanence.enable  = true;
      nerv.impermanence.mode    = "full";  # "btrfs" (BTRFS rollback) | "full" (/ as tmpfs, server)
    };
```

### nixosConfigurations.server block (modeled on host block, lines 76–87 of flake.nix)

```nix
      # Headless server — SSH only, LVM layout, full tmpfs impermanence.
      server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          impermanence.nixosModules.impermanence
          disko.nixosModules.disko
          self.nixosModules.default
          server
          ./hosts/configuration.nix
        ];
      };
```

### Module header after `# Profiles :` insertion — disko.nix example

```
# modules/system/disko.nix
#
# Declarative disk layout and layout-conditional initrd config. btrfs (desktop) or lvm (server). No default — must be set explicitly.
# Profiles : host layout=btrfs | server layout=lvm

{ config, lib, pkgs, ... }:
```

### README snapshot step (new step 7)

```bash
# 7. Create the BTRFS rollback baseline — must be done before nixos-install.
# Required: @root-blank is the clean-root template — initrd deletes @ and restores from this on every boot.
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
```

### modules/system/default.nix line 13 — before and after

Before:
```nix
    ./disko.nix         # declarative disk layout — conditional LVM LVs based on impermanence mode
```

After:
```nix
    ./disko.nix         # declarative disk layout (btrfs/lvm) with layout-conditional initrd services
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `nixosConfigurations.host` output | `host` + `server` outputs | Phase 13 | `nix eval .#nixosConfigurations.server.*` works; DISKO-02 and PROF-02 satisfied |
| README Section A ends at step 13 | Section A has 14 steps | Phase 13 | Operators get the `@root-blank` step; PROF-04 satisfied |
| Module headers have no profile cross-reference | Headers include `# Profiles :` line | Phase 13 | PROF-03 satisfied |
| `default.nix` line 13 references impermanence mode | Comment references layout + initrd services | Phase 13 | Accurate documentation |

**Deprecated/outdated:**
- `modules/system/default.nix` comment "conditional LVM LVs based on impermanence mode": wrong since Phase 9 moved layout branching to `nerv.disko.layout`; Phase 13 corrects it.

---

## Open Questions

1. **Whether to add `nerv.openssh.enable = true` to the `server` let-binding**
   - What we know: `nerv.openssh.enable` defaults to `false`. The `server` profile is headless and needs SSH. The README Profiles table says server has "SSH only".
   - What's unclear: Should the flake-level profile reflect the intended-use recommendation (explicit `true`) or minimal non-default divergence (omit, let operator set it)?
   - Recommendation: Omit from the locked `server` let-binding for now (Claude's discretion). The three locked options (`disko.layout`, `impermanence.enable`, `impermanence.mode`) are the structural requirements for DISKO-02 and PROF-02. Adding `openssh.enable` would be a documentation enhancement — reasonable, but not required by any of the five requirements. The planner should make this call; lean toward including it since the README already describes server as "SSH only" and the `host` binding models explicit declarations.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected (NixOS flake project — validation is `nix eval` and `nix flake check`) |
| Config file | N/A |
| Quick run command | `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` |
| Full suite command | `nix flake check` (requires `nix` on PATH; dev machine may lack it per STATE.md) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISKO-02 | `nixosConfigurations.server` resolves with `nerv.disko.layout = "lvm"` | smoke | `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` | ❌ Wave 0 (no test infra) |
| PROF-02 | `serverProfile` let-binding present in `flake.nix` | manual/grep | `grep -n "server" flake.nix` | ❌ Wave 0 |
| BOOT-02 | Rollback service unit defined (already implemented; doc gap only) | manual-only | Review `modules/system/disko.nix` rollback block | ✅ (code exists) |
| PROF-04 | README Section A contains `@root-blank` snapshot step | manual-only | `grep "@root-blank" README.md` | ❌ Wave 0 |
| PROF-03 | `# Profiles :` lines present in 3 module headers | manual/grep | `grep "# Profiles :" modules/system/disko.nix modules/system/boot.nix modules/system/impermanence.nix` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `grep`-based spot checks as noted in the test map above
- **Per wave merge:** `nix eval .#nixosConfigurations.server.config.nerv.disko.layout` if `nix` is available; otherwise manual inspection
- **Phase gate:** All grep checks green, README step numbers verified sequential 1–14, `nix eval` green before `/gsd:verify-work`

### Wave 0 Gaps

- No test framework to install — this is a Nix flake project; validation is via `nix` CLI or manual inspection
- `nix` may not be available on the dev machine (noted in STATE.md Phase 08 decision): "nix flake check skipped on dev machine (nix unavailable)"
- Fallback verification: manual file inspection + grep pattern checks for each requirement

*(If nix unavailable: "None — manual inspection + grep covers all phase requirements")*

---

## Sources

### Primary (HIGH confidence)

- `flake.nix` (read directly) — exact current structure of `let` block and `nixosConfigurations`
- `modules/system/disko.nix` (read directly) — exact current header and content
- `modules/system/boot.nix` (read directly) — exact current header
- `modules/system/impermanence.nix` (read directly) — exact current header
- `modules/system/default.nix` (read directly) — exact line 13 text
- `README.md` (read directly) — exact current step numbering and Section A content
- `.planning/phases/13-audit-gap-closure/13-CONTEXT.md` (read directly) — locked decisions
- `.planning/REQUIREMENTS.md` (read directly) — requirement IDs and descriptions
- `.planning/STATE.md` (read directly) — accumulated decisions

### Secondary (MEDIUM confidence)

None required — all findings sourced directly from project files.

### Tertiary (LOW confidence)

None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all inputs already in flake.nix; no new dependencies
- Architecture: HIGH — every pattern sourced directly from current codebase
- Pitfalls: HIGH — derived from actual file content and project decision history
- Validation: HIGH — grep-based checks are deterministic; nix eval availability caveat noted from STATE.md

**Research date:** 2026-03-12
**Valid until:** Indefinite — this is a closed codebase inspection, not an ecosystem survey. Findings are accurate until any of the five target files change.
