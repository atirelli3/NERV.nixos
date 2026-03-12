# Phase 12: Profile Wiring and Documentation - Research

**Researched:** 2026-03-10
**Domain:** NixOS flake profile wiring, module header documentation, README install procedure
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**vmProfile removal**
- Remove `vmProfile` let-binding entirely from `flake.nix`
- Remove `nixosConfigurations.vm` entirely from `flake.nix`
- No inline replacement — clean removal, not folded into another config

**hostProfile wiring**
- Add `nerv.disko.layout = "btrfs"` to hostProfile
- Change `nerv.impermanence.mode` from `"minimal"` → `"btrfs"`
- All other hostProfile options remain unchanged

**serverProfile wiring**
- Add `nerv.disko.layout = "lvm"` to serverProfile
- `nerv.impermanence.mode = "full"` stays as-is (no change)
- All other serverProfile options remain unchanged

**nerv.impermanence.mode ownership**
- Mode stays profile-level only (set in flake.nix profiles)
- `hosts/configuration.nix` does NOT get a `nerv.impermanence.mode` PLACEHOLDER
- Machine identity stays disk-level only; feature modes stay in profiles

**hosts/configuration.nix header**
- Remove `vmProfile` references from the Role/comments section
- No other changes to `configuration.nix` content

**Module headers (disko.nix, boot.nix, impermanence.nix)**
- Update all three headers to add Phase 12 profile cross-references:
  - Note which profile consumes which layout/mode
  - e.g. "hostProfile: layout=btrfs, mode=btrfs | serverProfile: layout=lvm, mode=full"
- No new option documentation needed — headers already current from Phases 9–11

**README.md — BTRFS install subsection**
- Add `### B — BTRFS layout (hostProfile)` subsection inside the existing Installation section
- Full walkthrough: same steps as Section A, but with an explicit step after disko:
  ```
  btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
  ```
- Order explicitly documented: run disko → create @root-blank → nixos-install
- Include pre-requisites and full commands with flags (user requested full walkthrough)
- nixos-install target: `#host`

**README.md — Profiles table and stale content**
- Remove `vm` row from the Profiles table
- Update the Profiles table descriptions for host/server to reflect btrfs/lvm layout
- Update "What NERV provides" description for impermanence: replace `minimal` mode
  references with `btrfs` mode (BTRFS rollback-on-boot for desktop)

**README.md — Repository Layout**
- Update Repository Layout section to reflect actual current file structure:
  - Replace `disko-configuration.nix` with `disko.nix` (in `modules/system/`)
  - Add `impermanence.nix` to module list
  - Update `boot.nix` description to "layout-agnostic initrd + bootloader"
  - Remove any references to removed or renamed files

### Claude's Discretion

- Exact wording of the BTRFS install subsection prose and callout formatting
- Whether to add a Warning block (like Section A) for the snapshot step
- Exact cross-reference wording in module headers
- Order of steps within the BTRFS README subsection (can mirror Section A structure)

### Deferred Ideas (OUT OF SCOPE)

- None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PROF-01 | `hostProfile` in `flake.nix` declares `nerv.disko.layout = "btrfs"` and `nerv.impermanence.mode = "btrfs"` | Direct attribute additions to existing hostProfile attrset; aligned `=` padding must be preserved |
| PROF-02 | `serverProfile` declares `nerv.disko.layout = "lvm"` explicitly; vmProfile REMOVED (user override of original requirement) | serverProfile gets one new attribute; vmProfile let-binding and nixosConfigurations.vm both deleted |
| PROF-03 | Section-header comments on `disko.nix`, `boot.nix`, and `impermanence.nix` updated to reflect new options and behavior | Each header gets a Profiles cross-reference line; no option table additions needed |
| PROF-04 | Install procedure documents required post-disko manual step: `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank` | README.md gets a new `### B — BTRFS layout (hostProfile)` subsection mirroring Section A structure |
</phase_requirements>

---

## Summary

Phase 12 is a pure wiring-and-documentation phase. No module logic changes. All work is confined to three kinds of edits: (1) attribute additions and deletions in `flake.nix`, (2) comment header updates in three `.nix` module files, and (3) prose and structural updates to `README.md`.

The existing codebase is in a clean state after Phases 9–11. The option types (`nerv.disko.layout` enum, `nerv.impermanence.mode` enum) are fully implemented and validated. Profiles in `flake.nix` currently use `nerv.impermanence.mode = "minimal"` (hostProfile) — this value is invalid under the Phase 11 enum `[ "btrfs" "full" ]`, making it a build-breaking stale value that must be corrected as part of PROF-01. The vmProfile block and `nixosConfigurations.vm` reference a non-existent `"minimal"` mode and would also fail evaluation; their removal in PROF-02 resolves this.

The BTRFS README install subsection (PROF-04) must precisely document the mandatory ordering: disko run → @root-blank snapshot → nixos-install. The snapshot step cannot be skipped — without it the Phase 10 rollback service (`btrfs subvolume snapshot /btrfs_tmp/@root-blank /btrfs_tmp/@`) has no source subvolume and will fail on first boot.

**Primary recommendation:** Treat PROF-01 and PROF-02 as a single atomic edit to `flake.nix` (all profile changes together), then address module headers and README independently.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Nix flake attrsets | NixOS 25.11 | Profile let-bindings in flake.nix | Native — no external dependency |
| NixOS module system | NixOS 25.11 | Header comment conventions | Native — established in Phase 6 |
| Markdown | — | README.md prose and section structure | Project documentation standard |

No external libraries are introduced or changed in this phase. All tooling is already present.

**Installation:** None — this phase makes no dependency changes.

---

## Architecture Patterns

### Existing Profile Structure (flake.nix)

The profiles are plain Nix attrsets in `let` bindings, passed directly in the `modules` list of each `nixosConfigurations` entry. This is the established pattern from Phase 8.

```nix
# Existing pattern — Phase 8 decision: "Three profiles as plain attrsets in let bindings"
let
  hostProfile = {
    nerv.openssh.enable      = true;
    nerv.audio.enable        = true;
    # ... aligned = signs
  };
in {
  nixosConfigurations.host = nixpkgs.lib.nixosSystem {
    modules = [ ... hostProfile ... ];
  };
}
```

After Phase 12, `hostProfile` gains two attributes; `serverProfile` gains one; `vmProfile` and `nixosConfigurations.vm` are deleted entirely.

### Alignment Convention

Existing profiles use aligned `=` padding (longest key determines the column). New attributes must fit into the existing column width. The current longest key in hostProfile is `nerv.impermanence.enable` (22 chars). `nerv.disko.layout` (17 chars) and `nerv.impermanence.mode` (22 chars) already present fit within that column.

Current hostProfile attribute column: 26 characters of key + spaces to reach `=`.

```nix
# Current hostProfile (verified from flake.nix):
nerv.openssh.enable       = true;   # key=20, padded to col 26
nerv.audio.enable         = true;   # key=17, padded to col 26
nerv.bluetooth.enable     = true;   # key=21, padded to col 26
nerv.printing.enable      = true;   # key=20, padded to col 26
nerv.secureboot.enable    = false;  # key=22, padded to col 26
nerv.impermanence.enable  = true;   # key=24, padded to col 26
nerv.impermanence.mode    = "minimal";  # key=22, padded to col 26
nerv.zsh.enable           = true;   # key=15, padded to col 26
nerv.home.enable          = true;   # key=16, padded to col 26
```

`nerv.disko.layout` (18 chars) must be padded to column 26 (8 spaces). This fits the existing alignment naturally.

### Module Header Convention

Established in Phase 6 (DOCS-01). Headers use `# Purpose :`, `# Options :`, `# Defaults :`, `# Override :`, `# Note :` sections. Cross-references are placed in the section most relevant to the information.

The Phase 12 cross-reference belongs in a new `# Profiles :` line (or appended to `# Note :` if a Profiles section would be redundant). Based on existing headers:

- `disko.nix` — add `# Profiles :` line (it has `# LUKS :` as a precedent for specialized sections)
- `boot.nix` — append to `# Note :` (short header, no specialized sections)
- `impermanence.nix` — add `# Profiles :` line (has multi-section header)

### README Section Structure

The README Installation section uses lettered subsections: `### A — New system (NixOS Live ISO)`, `### B — Existing NixOS system`, `### C — Enabling Secure Boot`. The new BTRFS subsection inserts between A and B, becoming:

- `### A — New system (NixOS Live ISO)` (LVM layout, unchanged)
- `### B — BTRFS layout (hostProfile)` (new)
- `### C — Existing NixOS system` (re-lettered from B, or left as B if insertion before B)

Wait — checking CONTEXT.md: the user specified adding `### B — BTRFS layout (hostProfile)` inside the existing Installation section. The existing `### B — Existing NixOS system` becomes `### C`. The existing `### C — Enabling Secure Boot` becomes `### D`. The lettering shift must be consistent throughout the document.

### Anti-Patterns to Avoid

- **Stale `"minimal"` mode reference:** `nerv.impermanence.mode = "minimal"` in hostProfile is build-breaking against the Phase 11 enum. Do not leave it in place.
- **Partial vmProfile removal:** `vmProfile` let-binding and `nixosConfigurations.vm` must both be removed in the same edit. Removing only one leaves a dangling reference that breaks `nix flake check`.
- **nerv.impermanence.mode in configuration.nix:** CONTEXT.md explicitly forbids adding a mode PLACEHOLDER to `hosts/configuration.nix`. Mode is profile-level only.
- **README Section A modification:** Section A (LVM new-system install) must not be altered — it documents the server install path and remains correct as-is.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Nix alignment | Custom formatter/script | Manual alignment matching existing style | One-time edit; scripting would introduce risk |
| README validation | Manual link check | Visual review sufficient | No automated link checker in scope |

**Key insight:** This phase has no algorithmic content. All edits are mechanical text changes. The risk is omission (forgetting a reference), not logic error.

---

## Common Pitfalls

### Pitfall 1: Stale "minimal" Mode Value

**What goes wrong:** `nerv.impermanence.mode = "minimal"` in hostProfile fails `nix flake check` because the Phase 11 enum is `[ "btrfs" "full" ]` — "minimal" is not a valid value.
**Why it happens:** The enum was narrowed in Phase 11 but the profile was not updated simultaneously.
**How to avoid:** PROF-01 corrects this: change `"minimal"` → `"btrfs"` as part of the same edit.
**Warning signs:** `nix flake check` error mentioning `nerv.impermanence.mode` not matching enum.

### Pitfall 2: Incomplete vmProfile Removal

**What goes wrong:** Removing `vmProfile` let-binding but leaving `nixosConfigurations.vm` (or vice versa) produces a Nix evaluation error — `vmProfile` undefined, or `nixosConfigurations.vm` references a deleted binding.
**Why it happens:** Two separate code blocks must both be deleted in one logical change.
**How to avoid:** Delete both in the same file edit. Verify with `nix flake check` (or grep for remaining `vmProfile` references).
**Warning signs:** `error: undefined variable 'vmProfile'` from Nix evaluator.

### Pitfall 3: README Section Re-lettering

**What goes wrong:** Inserting `### B — BTRFS layout` without re-lettering the subsequent sections, leaving two `### B —` headings and breaking the alphabetical structure.
**Why it happens:** Oversight when inserting between existing subsections.
**How to avoid:** Re-letter `### B — Existing NixOS system` → `### C`, and `### C — Enabling Secure Boot` → `### D` in the same edit.

### Pitfall 4: @root-blank Snapshot Step Ordering

**What goes wrong:** README documents snapshot step after nixos-install, or omits the ordering context. Users who miss the step get a broken first boot (rollback service has no `@root-blank` to snapshot from).
**Why it happens:** The snapshot is between disko and nixos-install — a non-obvious interrupt in the standard flow.
**How to avoid:** PROF-04 step sequence: disko run (step 4) → `btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank` (step 5, new) → nixos-install (step 6, renumbered from 5). Include a callout (Warning block or bold note) emphasizing it must precede nixos-install.
**Warning signs:** First boot fails with rollback service error about missing `@root-blank`.

### Pitfall 5: Wrong disko.nix Path in README Repository Layout

**What goes wrong:** README currently shows `hosts/disko-configuration.nix` in the Repository Layout, but the actual file is `modules/system/disko.nix` (moved in Phase 9). Leaving the stale path confuses users navigating the repo.
**Why it happens:** Repository Layout in README was not updated when disko.nix was introduced in Phase 9.
**How to avoid:** Replace `hosts/disko-configuration.nix` with `modules/system/disko.nix` in the layout tree; update description to match.

### Pitfall 6: impermanence.nix Missing from Repository Layout

**What goes wrong:** `modules/system/impermanence.nix` exists (from Phase 8/11) but is listed in README as `impermanence.nix` without the BTRFS mode in the description, or not listed at all.
**How to avoid:** Add or update the `impermanence.nix` line in the Repository Layout section.

---

## Code Examples

Verified patterns from existing codebase (read 2026-03-10):

### Current hostProfile (flake.nix lines 35–45) — before change

```nix
hostProfile = {
  nerv.openssh.enable       = true;
  nerv.audio.enable         = true;
  nerv.bluetooth.enable     = true;
  nerv.printing.enable      = true;
  nerv.secureboot.enable    = false;
  nerv.impermanence.enable  = true;
  nerv.impermanence.mode    = "minimal";  # STALE — invalid under Phase 11 enum
  nerv.zsh.enable           = true;
  nerv.home.enable          = true;
};
```

### Target hostProfile (after PROF-01)

```nix
# hostProfile — classic desktop/laptop configuration.
# openssh, audio, bluetooth, printing enabled. BTRFS impermanence: rollback resets root on each boot.
# Enable nerv.secureboot.enable = true after running sbctl enroll-keys on the target machine.
hostProfile = {
  nerv.disko.layout         = "btrfs";
  nerv.openssh.enable       = true;
  nerv.audio.enable         = true;
  nerv.bluetooth.enable     = true;
  nerv.printing.enable      = true;
  nerv.secureboot.enable    = false;
  nerv.impermanence.enable  = true;
  nerv.impermanence.mode    = "btrfs";
  nerv.zsh.enable           = true;
  nerv.home.enable          = true;
};
```

### Target serverProfile (after PROF-02)

```nix
# serverProfile — headless server configuration.
# openssh only. Full impermanence: / is tmpfs, state persisted to /persist.
# Requires impermanence.nixosModules.impermanence in modules list (see nixosConfigurations.server).
serverProfile = {
  nerv.disko.layout         = "lvm";
  nerv.openssh.enable       = true;
  nerv.audio.enable         = false;
  nerv.bluetooth.enable     = false;
  nerv.printing.enable      = false;
  nerv.secureboot.enable    = false;
  nerv.impermanence.enable  = true;
  nerv.impermanence.mode    = "full";
  nerv.zsh.enable           = true;
  nerv.home.enable          = false;
};
```

### vmProfile and nixosConfigurations.vm — deleted entirely

Lines 63–74 (vmProfile let-binding) and lines 114–126 (nixosConfigurations.vm block) are removed. No stub, no comment.

### Module header cross-reference pattern (disko.nix)

Append after existing `# LUKS :` section:

```
# Profiles : hostProfile   → layout = btrfs, impermanence.mode = btrfs
#            serverProfile → layout = lvm,   impermanence.mode = full
```

### Module header cross-reference pattern (boot.nix)

Append to existing `# Note :` section (or add a separate `# Profiles :` line):

```
# Profiles : hostProfile (btrfs layout) and serverProfile (lvm layout) both use this module.
#            Layout-conditional initrd config lives in disko.nix, not here.
```

### Module header cross-reference pattern (impermanence.nix)

Append after existing `# Note :` section:

```
# Profiles : hostProfile   → mode = btrfs (BTRFS rollback, /persist @persist subvolume)
#            serverProfile → mode = full  (/ as tmpfs, /persist LV)
```

### hosts/configuration.nix header — Role line fix

```
# Role     : Declares machine-specific values only. All service and feature
#            settings are controlled by the profile in flake.nix (hostProfile
#            or serverProfile).
```

Remove the `or vmProfile` reference that currently ends the line.

### README @root-blank install step (Section B — BTRFS)

```bash
# 4b. Create the @root-blank rollback baseline (BTRFS only — mandatory before nixos-install).
#     The initrd rollback service snapshots @root-blank → @ on every boot.
#     Skipping this step causes first-boot failure.
btrfs subvolume snapshot -r /mnt/@ /mnt/@root-blank
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `nerv.impermanence.mode = "minimal"` in hostProfile | `"btrfs"` | Phase 11 enum change | Build-breaking stale value — must be corrected here |
| `vmProfile` and `nixosConfigurations.vm` exist | Removed entirely | Phase 12 decision | Simplifies flake; vm path was never hardware-tested |
| `hosts/disko-configuration.nix` | `modules/system/disko.nix` | Phase 9 | README Repository Layout section is stale |
| Two impermanence modes: `minimal`/`full` | Two modes: `btrfs`/`full` | Phase 11 | README module reference table shows stale `minimal` |

**Deprecated/outdated in current README:**
- `"minimal"` mode description in the impermanence.nix option table (line 341) — must become `"btrfs"`
- `hosts/disko-configuration.nix` in Repository Layout tree — must become `modules/system/disko.nix`
- `vm` row in Profiles table — remove
- `hosts/disko-configuration.nix` reference in Section A instruction (line 64) — check if this refers to the old location vs the disko run command URL; the `disko run` command on line 68 already uses `github:nix-community/disko/v1.13.0` directly, not the local file path, so verify whether the `nano hosts/disko-configuration.nix` step (line 66) is still accurate for BTRFS users

---

## Open Questions

1. **README Section A — disko-configuration.nix reference**
   - What we know: Section A step 3 says `nano hosts/disko-configuration.nix`. The actual file is `hosts/disko-configuration.nix` at the hosts/ root (confirmed from Phase 8 decision: "hosts/disko-configuration.nix at hosts/ root"). Step 4 runs disko pointing to `hosts/disko-configuration.nix`.
   - What's unclear: Whether Section A is entirely for LVM or also covers BTRFS (the new Section B covers BTRFS). If Section A remains LVM-only, it is correct as-is. The planner should clarify in the plan: Section A = LVM install (server), Section B = BTRFS install (host).
   - Recommendation: Keep Section A unchanged. Section B for BTRFS is the new addition.

2. **PROF-02 requirement text vs user decision**
   - What we know: REQUIREMENTS.md PROF-02 says "serverProfile and vmProfile declare nerv.disko.layout = lvm explicitly". The user's CONTEXT.md decision overrides: vmProfile is removed entirely.
   - What's unclear: Nothing — CONTEXT.md is authoritative per research instructions.
   - Recommendation: Planner should implement PROF-02 as "serverProfile gets layout=lvm; vmProfile removed" (CONTEXT.md interpretation). The REQUIREMENTS.md text is superseded by user decision.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — NixOS/Nix evaluation; no unit test framework in repo |
| Config file | N/A |
| Quick run command | `nix flake check --no-build` (in /Users/nemesixsrl/Developemnt/NERV.nixos) |
| Full suite command | `nix flake check` (includes build; may be unavailable on dev machine per Phase 8 precedent) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROF-01 | hostProfile has `nerv.disko.layout = "btrfs"` and `nerv.impermanence.mode = "btrfs"` | smoke | `grep -n 'nerv.disko.layout\|nerv.impermanence.mode' flake.nix` | ✅ |
| PROF-01 | `"minimal"` no longer appears in flake.nix profiles | smoke | `grep -c '"minimal"' flake.nix` (expect 0) | ✅ |
| PROF-02 | `vmProfile` and `nixosConfigurations.vm` absent from flake.nix | smoke | `grep -c 'vmProfile\|\.vm ' flake.nix` (expect 0) | ✅ |
| PROF-02 | serverProfile has `nerv.disko.layout = "lvm"` | smoke | `grep -A20 'serverProfile' flake.nix \| grep 'disko.layout'` | ✅ |
| PROF-03 | Module headers contain profile cross-reference | smoke | `grep -n 'Profiles' modules/system/disko.nix modules/system/boot.nix modules/system/impermanence.nix` | ✅ |
| PROF-04 | README contains @root-blank snapshot command | smoke | `grep -c 'root-blank' README.md` (expect ≥ 2: disko.nix header ref + new README step) | ✅ |
| PROF-04 | README Section B exists with BTRFS heading | smoke | `grep -c 'BTRFS layout' README.md` (expect ≥ 1) | ✅ |

Note: `nix flake check --no-build` is the strongest automated verification for PROF-01/PROF-02, but it requires Nix to be available. On the dev machine (macOS, Darwin), `nix flake check` may not be available (Phase 8 precedent: "nix flake check skipped on dev machine"). Grep-based checks are the fallback.

### Sampling Rate

- **Per task commit:** `grep`-based smoke checks as listed above
- **Per wave merge:** All grep checks pass; `nix flake check --no-build` if Nix available
- **Phase gate:** All grep checks green before `/gsd:verify-work`

### Wave 0 Gaps

None — existing infrastructure (Nix evaluator + grep) covers all phase requirements. No new test files needed.

---

## Sources

### Primary (HIGH confidence)

- Existing `flake.nix` (read 2026-03-10) — current profile state, alignment style, vmProfile/nixosConfigurations.vm exact location
- Existing `modules/system/disko.nix` (read 2026-03-10) — current header format, established `# LUKS :` specialized section precedent
- Existing `modules/system/boot.nix` (read 2026-03-10) — current header format, minimal structure
- Existing `modules/system/impermanence.nix` (read 2026-03-10) — current header format, mode enum `[ "btrfs" "full" ]` confirmed
- Existing `hosts/configuration.nix` (read 2026-03-10) — current header, vmProfile reference location
- Existing `README.md` (read 2026-03-10) — current profiles table, installation sections, repository layout, impermanence description
- `.planning/phases/12-profile-wiring-and-documentation/12-CONTEXT.md` (read 2026-03-10) — locked decisions, discretion areas
- `.planning/REQUIREMENTS.md` (read 2026-03-10) — PROF-01 through PROF-04 definitions
- `.planning/STATE.md` (read 2026-03-10) — accumulated decisions from all prior phases

### Secondary (MEDIUM confidence)

None required — all findings are grounded in direct code inspection of the repo.

### Tertiary (LOW confidence)

None.

---

## Metadata

**Confidence breakdown:**
- Flake profile edits: HIGH — exact current state read; changes are additive attribute insertions and block deletions
- Module header updates: HIGH — existing header format read; pattern established in Phase 6/10
- README updates: HIGH — exact current README read; stale references confirmed by inspection
- Validation: HIGH — grep-based checks are deterministic; nix flake check availability flagged as conditional

**Research date:** 2026-03-10
**Valid until:** N/A — this phase targets a stable, version-controlled codebase; findings reflect current repo state
