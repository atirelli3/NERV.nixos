# Phase 11: Impermanence BTRFS Mode - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend `modules/system/impermanence.nix` with a `"btrfs"` impermanence mode.
In btrfs mode: root stays on the BTRFS `@` subvolume (reset by the Phase 10 rollback service, not tmpfs);
`environment.persistence` bind-mounts persistent state from `/persist` (@persist subvolume).
This is the desktop/laptop counterpart to `"full"` mode (server: / as tmpfs).

Phase 11 does NOT wire profiles (Phase 12) or update section-header comments (Phase 12).

</domain>

<decisions>
## Implementation Decisions

### Mode enum redesign (breaking change)

- Drop `"minimal"` mode entirely — the /tmp + /var/tmp tmpfs mounts are removed from the module
- Enum becomes `["btrfs", "full"]` with **no default** — callers must declare mode explicitly
  (consistent with `nerv.disko.layout` which also has no default)
- Hosts that want tmpfs /tmp should set `boot.tmp.useTmpfs = true` directly in their config
- This is a breaking change to the existing module; existing hosts using `mode = "minimal"` will
  get an eval error until they update their config — acceptable since no production hosts exist yet

### btrfs mode persistence list

`environment.persistence."/persist"` in btrfs mode declares:

**directories:**
- `/var/lib` — single broad entry covers everything: nixos uid/gid state, systemd timers,
  sbctl keys, bluetooth, NetworkManager, cups, upower, and any future additions.
  No need to enumerate subdirs individually.
- `/etc/nixos` — NERV.nixos repo clone; must survive rollback

**files:**
- `/etc/machine-id`
- `/etc/ssh/ssh_host_ed25519_key`
- `/etc/ssh/ssh_host_ed25519_key.pub`
- `/etc/ssh/ssh_host_rsa_key`
- `/etc/ssh/ssh_host_rsa_key.pub`

**explicitly excluded:**
- `/var/log` — persisted by the `@log` BTRFS subvolume; a bind-mount would conflict

`hideMounts = true` (same as full mode).

### sbctl safety assertion

Add an assertion (or `lib.warn`) that fires when:
- `cfg.mode == "btrfs"` AND `config.nerv.secureboot.enable == true`
  AND `/var/lib` (or `/var/lib/sbctl`) is NOT reachable from `environment.persistence."/persist".directories`

This is belt-and-suspenders: with `/var/lib` as a whole entry, sbctl is automatically covered.
The assertion catches edge cases where someone strips the persistence list and forgets sbctl.

### neededForBoot

Set `fileSystems."/persist".neededForBoot = lib.mkDefault true` in btrfs mode,
following the same pattern as full mode. Even though disko already mounts @persist,
the explicit override ensures the impermanence bind-mounts are available before
systemd-tmpfiles and service activation. The `lib.mkDefault` allows overrides.

### Code structure

Use a separate `(lib.mkIf (cfg.mode == "btrfs") { ... })` block inside `lib.mkMerge`,
parallel to the existing `(lib.mkIf (cfg.mode == "full") { ... })` block.
Do NOT share code between btrfs and full blocks — they differ in:
- btrfs: no `/` override (no tmpfs root)
- btrfs: no `/var/log` in persistence (full mode includes it)
The separation makes each mode self-documenting.

### Claude's Discretion

- Exact Nix attribute path for the assertion (assert vs lib.warn)
- Whether to update the module header comment in this phase or leave it for Phase 12

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true` — already used in full mode; replicate for btrfs mode
- `environment.persistence."${cfg.persistPath}" { hideMounts = true; ... }` — full mode block is the direct template
- `persistPath` option already exists (default: "/persist") — btrfs mode uses it the same way

### Established Patterns

- `lib.mkMerge [ (lib.mkIf condA { ... }) (lib.mkIf condB { ... }) ]` — existing module structure; btrfs block is a third entry
- No default on enum options (`nerv.disko.layout`) — replicate for `nerv.impermanence.mode`

### Integration Points

- `config.nerv.secureboot.enable` — referenced by the sbctl assertion (already imported via `config`)
- `cfg.persistPath` — used as the environment.persistence key; btrfs mode uses same option
- `impermanence.nixosModules.impermanence` — must be in the host's modules list for environment.persistence to work (same requirement as full mode; documented in module header)

### Breaking change scope

The `minimal` mode removal affects:
- `modules/system/impermanence.nix` — remove `"minimal"` from enum, remove tmpfs fileSystems block
- `hosts/configuration.nix` — will need `nerv.impermanence.mode = "btrfs"` set explicitly (Phase 12)
- Any profile that used `mode = "minimal"` implicitly via the default — will error until updated

</code_context>

<specifics>
## Specific Ideas

- "In the spec it should be specified that /var/lib is in the persist directory (when in btrfs mode),
  so everything under /var/lib/* is persist" — single broad /var/lib entry, not individual subdirs
- Two real modes going forward: `"btrfs"` (desktop, @root-blank rollback) and `"full"` (server, / as tmpfs).
  Minimal mode was a stepping-stone, not a target architecture.

</specifics>

<deferred>
## Deferred Ideas

- Per-user persistence (e.g. /home/demon on /persist) — explicitly out of scope per PROJECT.md
  ("Full home impermanence ($HOME on tmpfs) — too opinionated for a general base")
- VM-specific impermanence approach — Phase 12 or post-v2.0; VMs can use boot.tmp.useTmpfs = true
- extraPersistDirs option for user-extensible persistence — could be added in a future phase if needed

</deferred>

---

*Phase: 11-impermanence-btrfs-mode*
*Context gathered: 2026-03-10*
