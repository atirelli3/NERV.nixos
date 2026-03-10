# Phase 11: Impermanence BTRFS Mode - Research

**Researched:** 2026-03-10
**Domain:** NixOS module authoring — impermanence, fileSystems, lib.mkMerge/mkIf patterns
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Drop `"minimal"` mode entirely — /tmp and /var/tmp tmpfs mounts are removed from the module
- Enum becomes `["btrfs", "full"]` with **no default** — callers must declare mode explicitly
- Hosts that want tmpfs /tmp should set `boot.tmp.useTmpfs = true` directly
- This is a breaking change; acceptable because no production hosts exist yet
- `environment.persistence."/persist"` in btrfs mode: **directories** = `/var/lib`, `/etc/nixos`; **files** = `/etc/machine-id`, SSH host keys (ed25519 + rsa, pub+priv)
- `/var/log` explicitly excluded from persistence (persisted by @log BTRFS subvolume; bind-mount would conflict)
- `hideMounts = true` in btrfs mode (same as full mode)
- sbctl safety assertion fires when `cfg.mode == "btrfs"` AND `nerv.secureboot.enable == true` AND `/var/lib` (or `/var/lib/sbctl`) is NOT reachable from persistence list
- `fileSystems."/persist".neededForBoot = lib.mkDefault true` in btrfs mode, following same pattern as full mode
- Use a separate `(lib.mkIf (cfg.mode == "btrfs") { ... })` block inside `lib.mkMerge`, parallel to the `"full"` block — do NOT share code between the two blocks

### Claude's Discretion

- Exact Nix attribute path for the assertion (assert vs lib.warn)
- Whether to update the module header comment in this phase or leave it for Phase 12

### Deferred Ideas (OUT OF SCOPE)

- Per-user persistence (e.g. /home/demon on /persist) — explicitly out of scope per PROJECT.md
- VM-specific impermanence approach — Phase 12 or post-v2.0
- extraPersistDirs option for user-extensible persistence — possible future phase
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PERSIST-01 | `nerv.impermanence.mode = "btrfs"` activates `environment.persistence."/persist"` without a tmpfs `/`; persistence rules declare machine-id, SSH host keys, `/var/lib/nixos`, `/var/lib/systemd`, `/etc/nixos`; `/var/log` excluded | Covered by: existing full-mode template (direct analogue), impermanence module `directories` semantics, BTRFS @log subvolume conflict rationale |
| PERSIST-02 | `/persist` (@persist subvolume) has `neededForBoot = true` in btrfs mode so impermanence bind-mounts are available before services start | Covered by: disko neededForBoot research flag resolution, existing `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` pattern in full mode |
</phase_requirements>

---

## Summary

Phase 11 extends `modules/system/impermanence.nix` with a `"btrfs"` impermanence mode and simultaneously drops the legacy `"minimal"` mode, leaving the enum as `["btrfs", "full"]` with no default. The btrfs mode is the desktop/laptop counterpart to `"full"` (server): rather than mounting `/` as tmpfs, the BTRFS rollback service (Phase 10) resets root on every boot, and `environment.persistence` bind-mounts selective state from `/persist` (@persist subvolume). The implementation is a near-direct parallel of the existing `"full"` block — the primary differences are the absence of the tmpfs `/` mount and the exclusion of `/var/log` from the persistence list.

The key research flag from the project state — whether disko v1.13.0 supports `neededForBoot` natively on BTRFS subvolume mounts — is **resolved as NO**. Disko maintainers explicitly closed the request as a duplicate and stated that "doing it via fileSystems is the expected way." This means the existing pattern in the `"full"` block (`fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true`) is the correct and authoritative approach for the btrfs block too. No separate disko-level configuration is needed or supported.

The `/var/lib` single broad entry in `environment.persistence` directories is safe in btrfs mode specifically because the BTRFS root (`@`) is wiped to the `@root-blank` baseline on every boot, guaranteeing that `/var/lib` is empty before the bind mount executes at stage-2 activation. This eliminates the known impermanence pitfall where bind-mounting a directory that already contains content silently hides existing files.

**Primary recommendation:** Implement the btrfs block as a self-contained `lib.mkIf (cfg.mode == "btrfs") { ... }` entry appended to the existing `lib.mkMerge` list; set `neededForBoot` via `fileSystems`, not via disko; use `lib.warn` rather than a hard `assertion` for the sbctl safety check to avoid evaluation failure during transitions.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| nix-community/impermanence | pinned in flake.nix (no version tag — tracks master) | Provides `environment.persistence` NixOS option and bind-mount activation service | Already wired in all nixosConfigurations; provides the only upstream NixOS module for declarative bind-mount persistence |
| NixOS module system (`lib.mkMerge`, `lib.mkIf`, `lib.mkDefault`) | nixpkgs-unstable | Mode-conditional config composition | Established project pattern, avoids pushDownProperties cycle; same approach used in disko.nix and existing impermanence.nix |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| disko v1.13.0 | pinned in flake.nix | Declares @persist subvolume → `/persist` mount | Already complete from Phase 9; Phase 11 does not touch disko.nix |
| lanzaboote (via nerv.secureboot) | pinned in flake.nix | sbctl key storage in `/var/lib/sbctl` | Referenced only for the sbctl safety assertion logic |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `fileSystems."/persist".neededForBoot` override in impermanence.nix | disko subvolume `neededForBoot` attribute | Disko does not support this option (issues #192 and #594 closed as "use fileSystems directly"); impermanence.nix override is the only correct path |
| `lib.warn` for sbctl assertion | hard `assert` | `assert` causes eval failure, which breaks `nix flake check` on hosts where secureboot config is in flux; `lib.warn` preserves build while alerting the operator |

**Installation:** No new packages required. All dependencies (impermanence input, disko input) are already declared in `flake.nix`.

---

## Architecture Patterns

### Recommended Module Structure

The btrfs block follows the existing `lib.mkMerge` structure in `impermanence.nix`. The updated `config` section becomes three entries:

```
lib.mkMerge [
  { /* shared: /tmp, /var/tmp fileSystems + extraDirs + users + IMPL-02 sbctl assertion */ }
  (lib.mkIf (cfg.mode == "full") { /* tmpfs /, neededForBoot, environment.persistence with /var/log */ })
  (lib.mkIf (cfg.mode == "btrfs") { /* neededForBoot only, environment.persistence without /var/log */ })
]
```

### Pattern 1: neededForBoot via fileSystems Override

**What:** Setting `neededForBoot = true` on a mount point by writing directly to `fileSystems."<path>"` in the NixOS module, separate from disko configuration.

**When to use:** Always — disko v1.13.0 does not expose `neededForBoot` in its subvolume type. The fileSystems approach is the official workaround confirmed by disko maintainers.

**Example:**
```nix
# Source: existing full-mode block in modules/system/impermanence.nix (line 119)
fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;
```

The `lib.mkDefault` wrapper allows host-level overrides while establishing the correct default for all impermanence-enabled hosts.

### Pattern 2: Parallel lib.mkIf Blocks for Mode Discrimination

**What:** Each mode gets a fully self-contained `lib.mkIf` block inside `lib.mkMerge`. No shared sub-expressions between modes.

**When to use:** When two modes configure overlapping but distinct sets of NixOS options. Sharing a sub-expression between modes would require extracting a let binding that would be evaluated eagerly by `pushDownProperties`, risking cycles.

**Example:**
```nix
# Source: existing structure in modules/system/impermanence.nix (lines 76-140)
config = lib.mkIf cfg.enable (lib.mkMerge [
  { /* common block */ }
  (lib.mkIf (cfg.mode == "full")  { /* full-only */ })
  (lib.mkIf (cfg.mode == "btrfs") { /* btrfs-only */ })
]);
```

### Pattern 3: Mode Enum with No Default

**What:** Declare `lib.types.enum ["btrfs" "full"]` with no `default` attribute.

**When to use:** Options that are meaningless without an explicit host decision. Consistent with `nerv.disko.layout`, `nerv.hostname`, `nerv.hardware.cpu`.

**Example:**
```nix
mode = lib.mkOption {
  type        = lib.types.enum [ "btrfs" "full" ];
  # intentionally no default — forces explicit declaration per host
  description = "...";
};
```

Removing `default = "minimal"` from the existing option definition achieves the breaking change. The `"minimal"` entry is simultaneously removed from the enum list.

### Pattern 4: sbctl Safety via lib.warn (Claude's Discretion)

**What:** `lib.warn` fires a build-time warning when btrfs mode is active, secureboot is enabled, and `/var/lib` (or a path that covers sbctl) is absent from the persistence list.

**When to use:** Safety assertions where hard eval failure is too disruptive (e.g., during a multi-step configuration migration).

**Example:**
```nix
# Recommended pattern for sbctl check in btrfs block
(lib.mkIf (cfg.mode == "btrfs") {
  # ... environment.persistence, fileSystems ...

  # Belt-and-suspenders: /var/lib as single entry already covers sbctl.
  # Warning fires only if someone strips the persistence list and forgets sbctl.
  warnings = lib.optionals
    (config.nerv.secureboot.enable &&
     !(lib.any
         (d: d == "/var/lib" || d == "/var/lib/sbctl" || lib.hasPrefix "/var/lib/sbctl" d)
         (cfg.persistDirs or [])))  # adapt to actual option structure
    [ "nerv: secureboot is enabled but /var/lib/sbctl is not covered by environment.persistence in btrfs mode — sbctl keys will be lost on reboot" ];
})
```

Note: the existing IMPL-02 assertion in the common block uses `assertions` (hard fail) because it guards against a different error: tmpfs paths that would *wipe* sbctl. The btrfs sbctl check is softer — it guards against *missing* persistence. `lib.warn` / `warnings` is appropriate for the latter.

### Anti-Patterns to Avoid

- **Sharing code between `"btrfs"` and `"full"` blocks:** Both modes configure `environment.persistence` and `fileSystems`, but their lists differ. Extracting a shared expression creates a let binding evaluated outside the `lib.mkIf` scope, which can cause push-down cycles. Keep each block self-contained.
- **Setting `neededForBoot` in disko.nix:** Not supported in disko v1.13.0. The option must be set in `impermanence.nix` via `fileSystems."${cfg.persistPath}".neededForBoot`.
- **Including `/var/log` in btrfs mode persistence:** `/var/log` is mounted from the `@log` BTRFS subvolume by disko. Adding it to `environment.persistence.directories` in btrfs mode would create a double-mount (bind over an already-mounted subvolume), which fails at stage-2 activation.
- **Using a hard `assert` for the sbctl check in btrfs mode:** Hard assertions break `nix flake check` during multi-step migrations. Use `warnings` instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bind-mount management for persistence | Custom systemd mount units or activation scripts | `environment.persistence` from `impermanence.nixosModules.impermanence` | Handles ordering, directory creation, hideMounts, and home-manager integration; custom solutions miss edge cases around activation timing |
| Early-boot mount ordering for /persist | Custom initrd script or `boot.initrd.postDeviceCommands` | `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` | NixOS stage-1/stage-2 already respects `neededForBoot`; `postDeviceCommands` is incompatible with `boot.initrd.systemd.enable = true` (already set in this project) |
| Mode-conditional config merging | `if/else` chains on `cfg.mode` at the top level | `lib.mkMerge [ (lib.mkIf ...) (lib.mkIf ...) ]` | `if/else` can trigger pushDownProperties evaluation cycles; lib.mkMerge is the established safe pattern in this codebase |

**Key insight:** The impermanence module from nix-community handles significant complexity around activation ordering and bind-mount lifecycle. The `neededForBoot` primitive in NixOS is the correct lever for mount ordering — reaching for initrd scripts or systemd overrides is unnecessary.

---

## Common Pitfalls

### Pitfall 1: Double-Mount of /var/log

**What goes wrong:** Adding `/var/log` to `environment.persistence."/persist".directories` in btrfs mode causes a bind-mount to be attempted over a path that is already mounted as the `@log` BTRFS subvolume (declared in `disko.nix`). The activation fails with a mount conflict error.

**Why it happens:** The full mode template includes `/var/log` in its persistence list because in full mode `/var/log` lives on the ephemeral tmpfs root and must be bind-mounted from `/persist`. In btrfs mode, `/var/log` is already a persistent BTRFS subvolume — no bind-mount is needed.

**How to avoid:** The btrfs block in `impermanence.nix` must explicitly omit `/var/log` from `directories`. This is a locked decision from CONTEXT.md.

**Warning signs:** Stage-2 activation error mentioning `/var/log` mount failure; `systemctl --failed` showing impermanence-related services.

### Pitfall 2: Bind-Mounting /var/lib Over Non-Empty Directory

**What goes wrong:** In general impermanence usage, bind-mounting a directory that already contains files silently hides the originals (standard bind-mount behavior). This can cause `/var/lib/nixos` (uid/gid state) or systemd state to disappear mid-session.

**Why it happens:** NixOS activation scripts populate parts of `/var/lib` during stage 2 before bind mounts are established.

**How to avoid:** This pitfall does NOT apply in btrfs mode for this project because the BTRFS rollback service (Phase 10) deletes `@` and re-snapshots `@root-blank → @` in the initrd, before stage 2. The root is clean at activation time. However, the `/persist/@var/lib` directory on the @persist subvolume must be pre-created at nixos-install time (or it will be empty and the bind mount source will be empty on first boot — which is correct behavior for initial setup).

**Warning signs:** Missing files in `/var/lib` that should have been persisted; only relevant if the root was not rolled back (which should not happen in normal btrfs mode operation).

### Pitfall 3: neededForBoot Not Set Leads to Late /persist Mount

**What goes wrong:** If `fileSystems."/persist".neededForBoot` is not `true`, NixOS may not mount `/persist` early enough in stage 2. The `environment.persistence` activation service attempts to create bind mounts before the source directory (`/persist/var/lib`, etc.) is available, causing activation failure or silent empty bind mounts.

**Why it happens:** NixOS uses `neededForBoot` to determine which filesystems must be mounted in early stage 2 (before most services). Without it, `/persist` could be mounted lazily or late.

**How to avoid:** Always set `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` in the btrfs block — directly mirroring the full mode block. This is a locked decision from CONTEXT.md.

**Warning signs:** `systemctl status impermanence.service` showing "source directory not found" or "no such file"; early-boot failures in persistence bind mounts.

### Pitfall 4: Removing "minimal" Default Breaks Hosts Before They Update

**What goes wrong:** Removing `default = "minimal"` from the `mode` option and removing `"minimal"` from the enum causes any host that does not explicitly declare `nerv.impermanence.mode` to get an eval error ("The option ... is used but not defined").

**Why it happens:** The option type `enum` with no default requires callers to set the option explicitly. This is the intended behavior (consistent with `nerv.disko.layout`), but it is a breaking change.

**How to avoid:** Document clearly in module header comment that the option has no default. The `hosts/configuration.nix` template should include an explicit `nerv.impermanence.mode = "btrfs"` (or be updated in Phase 12). No existing production hosts means this is acceptable.

**Warning signs:** `nix flake check` eval error: "The option 'nerv.impermanence.mode' is used but not defined".

### Pitfall 5: pushDownProperties Cycle from lib.mkMerge Misuse

**What goes wrong:** Placing a let binding that references `cfg.*` options at the top-level of the module (outside a `lib.mkIf` condition) can cause an evaluation cycle when `lib.mkMerge` tries to push the condition down into each attribute.

**Why it happens:** `pushDownProperties` in the NixOS module system evaluates contents of `lib.mkMerge` lists eagerly. If a let binding is referenced inside the merge and it references config options, a cycle can form.

**How to avoid:** The existing `extraDirFileSystems` and `userFileSystems` let bindings in the module avoid this by not being referenced inside `lib.mkIf` blocks that contain `fileSystems`. Keep all `cfg.*` references inside explicit `lib.mkIf` scopes. Do not extract shared sub-expressions between the btrfs and full blocks.

**Warning signs:** Nix eval error: "infinite recursion encountered".

---

## Code Examples

Verified patterns from the existing codebase (impermanence.nix):

### Existing full mode block (direct template for btrfs block)

```nix
# Source: modules/system/impermanence.nix lines 110-139
(lib.mkIf (cfg.mode == "full") {
  # / as tmpfs — reset on every reboot (Nix store on /nix, state on /persist)
  fileSystems."/" = {
    device  = "none";
    fsType  = "tmpfs";
    options = [ "defaults" "size=2G" "mode=755" ];
  };

  # /persist must be available before systemd-tmpfiles and impermanence bind mounts
  fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;

  # environment.persistence from nixos-community/impermanence module
  environment.persistence."${cfg.persistPath}" = {
    hideMounts = true;
    directories = [
      "/var/log"          # systemd journal, syslog
      "/var/lib/nixos"    # nixos user/group ID allocations (mutableUsers state)
      "/var/lib/systemd"  # systemd coredumps, timers, unit state
      "/etc/nixos"        # NERV.nixos repo — user clones here, must survive reboots
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
})
```

### Target btrfs block (derived from full mode, differences annotated)

```nix
# Proposed btrfs block — differences from full mode:
#   1. No fileSystems."/" (no tmpfs root; rollback service handles reset)
#   2. No "/var/log" in directories (@log subvolume already mounts it)
#   3. "/var/lib" replaces "/var/lib/nixos" + "/var/lib/systemd" (single broad entry)
(lib.mkIf (cfg.mode == "btrfs") {
  # /persist must be available before impermanence bind mounts
  # (disko declares the @persist subvolume mount but does not set neededForBoot —
  #  that is not supported in disko v1.13.0; must be set here via fileSystems)
  fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;

  # environment.persistence — bind mounts from /persist for desktop/laptop BTRFS mode
  environment.persistence."${cfg.persistPath}" = {
    hideMounts = true;
    directories = [
      "/var/lib"   # all service state: uid/gid (nixos), timers (systemd), sbctl, BT, NM, cups...
      "/etc/nixos" # NERV.nixos repo — must survive rollback
      # NOTE: /var/log intentionally omitted — persisted by @log BTRFS subvolume (disko.nix)
      #       Adding it here would create a double-mount conflict.
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
})
```

### Mode option redefinition (enum + no default)

```nix
mode = lib.mkOption {
  type        = lib.types.enum [ "btrfs" "full" ];
  # intentionally no default — forces explicit declaration per host;
  # consistent with nerv.disko.layout, nerv.hostname.
  description = ''
    Impermanence mode.
      btrfs — Root stays on BTRFS @; rollback service resets @ on each boot.
              /persist (@persist subvolume) holds state via environment.persistence.
              For desktop/laptop profiles. Requires nerv.disko.layout = "btrfs".
      full  — / as tmpfs (resets on reboot); /persist holds system state via
              environment.persistence. For server profiles.
              Requires impermanence.nixosModules.impermanence in modules list.
  '';
};
```

### minimal mode removal — what to delete

The following must be removed entirely:
- `"minimal"` from the enum in `mode` option
- `default = "minimal"` from the mode option
- The `/tmp` and `/var/tmp` fileSystems entries from the shared common block
- The `extraDirs` and `users` tmpfs logic is RETAINED (used by both remaining modes)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mode = "minimal"` (default) | No default; enum = `["btrfs", "full"]` | Phase 11 | Forces explicit declaration; eliminates implicit "safe" mode that silently did almost nothing |
| Individual `/var/lib/*` subdirs in persistence | Single `/var/lib` broad entry | Phase 11 (btrfs mode) | Simpler; automatically covers all future state dirs without re-editing the module |
| `/var/log` always in persistence | `/var/log` only in full mode | Phase 11 | Avoids double-mount conflict with @log BTRFS subvolume in btrfs mode |
| neededForBoot via disko config | `fileSystems."...".neededForBoot` override | Disko #192/#594 (unresolved) | Disko never added native support; the fileSystems approach is authoritative |

**Deprecated/outdated:**
- `mode = "minimal"`: removed entirely in Phase 11. Hosts must set `btrfs` or `full` explicitly.
- `/tmp` and `/var/tmp` tmpfs entries in impermanence.nix: removed in Phase 11. Hosts that want tmpfs /tmp should use `boot.tmp.useTmpfs = true`.

---

## Open Questions

1. **Header comment update: Phase 11 or Phase 12?**
   - What we know: CONTEXT.md leaves this to Claude's discretion
   - What's unclear: Phase 12 (PROF-03) explicitly requires header updates on impermanence.nix; updating now is technically correct but duplicates work
   - Recommendation: Update the header in Phase 11 to reflect the new `["btrfs", "full"]` enum and btrfs mode semantics. Phase 12 can refine/finalize if needed. Leaving an outdated header (still says "minimal" mode) during Phase 12's gap is confusing.

2. **sbctl assertion: `assertions` vs `warnings`**
   - What we know: The existing IMPL-02 check in the common block uses hard `assertions` for a different scenario (tmpfs paths that would wipe sbctl keys)
   - What's unclear: Whether hard failure is appropriate for the btrfs sbctl check (missing persistence vs. active erasure)
   - Recommendation: Use `warnings` (not `assertions`) for the btrfs sbctl check. The risk is different — missing persistence loses keys on next rollback, which is recoverable with re-enrollment; erasing sbctl via tmpfs wipes it immediately. `lib.warn` preserves `nix flake check` while alerting the operator.

3. **`/var/lib` as single broad entry — impermanence behavior**
   - What we know: The impermanence module supports string directory entries of any depth; the `/var/lib` directory will be empty on btrfs mode hosts (BTRFS rollback guarantees clean root before stage 2)
   - What's unclear: Whether impermanence's bind-mount service has special handling for parent directories vs. leaf directories (ordering, dependency injection for sub-mounts)
   - Recommendation: Proceed with `/var/lib` as the single entry per the locked decision. The bind-mount runs before services start (enforced by `neededForBoot` on `/persist`). If a future service adds a sub-mount under `/var/lib`, that is a configuration conflict to resolve at that point, not a pre-emptive concern.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — no test/ or tests/ directory, no pytest.ini, no jest.config.* |
| Config file | None — Wave 0 gap |
| Quick run command | `nix flake check` (eval-level correctness only) |
| Full suite command | `nix flake check` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PERSIST-01 | `nerv.impermanence.mode = "btrfs"` activates `environment.persistence."/persist"` with correct dirs/files; `/var/log` absent | eval/smoke | `nix eval .#nixosConfigurations.host.config.environment.persistence` — inspects output for expected paths | ❌ Wave 0 (no test infra; manual eval check) |
| PERSIST-02 | `fileSystems."/persist".neededForBoot` evaluates to `true` in btrfs mode | eval/smoke | `nixos-option fileSystems."/persist".neededForBoot` (on target) or `nix eval .#nixosConfigurations.host.config.fileSystems."/persist".neededForBoot` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `nix flake check` (evaluates all nixosConfigurations; catches type errors, enum violations, undefined option references)
- **Per wave merge:** `nix flake check`
- **Phase gate:** `nix flake check` green + manual `nix eval` spot-checks for PERSIST-01 and PERSIST-02 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] No automated test infra exists for NixOS module evaluation in this project — all validation is via `nix flake check` (eval) and `nixos-option` on a real system. This is consistent with all previous phases.
- [ ] `nix eval .#nixosConfigurations.host.config.environment.persistence` should be run manually to verify the persistence attribute set is correct before marking Phase 11 complete.
- [ ] `nix eval .#nixosConfigurations.host.config.fileSystems."/persist".neededForBoot` should evaluate to `true` when `nerv.impermanence.mode = "btrfs"`.

*(No new test files are needed or expected — this matches the test approach used for Phases 9 and 10.)*

---

## Sources

### Primary (HIGH confidence)

- Existing `modules/system/impermanence.nix` — direct template for btrfs block; patterns at lines 110-139 verified by inspection
- Existing `modules/system/disko.nix` — confirms @persist subvolume at `/persist`, @log subvolume at `/var/log`; no `neededForBoot` in subvolume config (confirmed absence)
- `flake.nix` — confirms `impermanence.nixosModules.impermanence` is already in all nixosConfigurations; confirms disko v1.13.0 pin
- `11-CONTEXT.md` — all locked decisions are authoritative per project process

### Secondary (MEDIUM confidence)

- [disko issue #594 "QUESTION: neededForBoot option"](https://github.com/nix-community/disko/issues/594) — closed as duplicate; maintainer states "doing it via fileSystems is the expected way" — resolves the phase research flag definitively
- [disko issue #192 "neededForBoot flag"](https://github.com/nix-community/disko/issues/192) — open as of January 2025; confirms no native disko support for neededForBoot; multiple contributors confirm fileSystems override is the workaround

### Tertiary (LOW confidence — informational only)

- [impermanence issue #169 "Handle bind mount of directory that already has content"](https://github.com/nix-community/impermanence/issues/169) — documents the bind-over-content pitfall; explains why btrfs rollback eliminates the risk in this project's setup
- [NixOS Discourse: Setting up Impermanence with disko and luks with btrfs](https://discourse.nixos.org/t/setting-up-impermanence-with-disko-and-luks-with-btrfs-and-also-nuking-everything-on-reboot/69423) — real-world confirmation of `fileSystems.${persistPath}.neededForBoot = true` pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already wired and pinned; no new dependencies
- Architecture: HIGH — btrfs block is a direct structural parallel to the existing full block; key design decisions locked in CONTEXT.md
- neededForBoot implementation: HIGH — research flag resolved via disko GitHub issues; fileSystems override is confirmed canonical approach
- /var/lib single-entry safety: MEDIUM — correct for btrfs mode (clean root guaranteed by rollback), but impermanence behavior with parent directories is not formally documented; risk is LOW given the rollback guarantee
- Pitfalls: HIGH — all identified pitfalls derive from existing code, disko/impermanence issue tracker, or locked decisions

**Research date:** 2026-03-10
**Valid until:** 2026-06-10 (stable domain — NixOS module system patterns are stable; disko/impermanence APIs change slowly)
