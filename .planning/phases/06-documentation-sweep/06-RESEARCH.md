# Phase 6: Documentation Sweep - Research

**Researched:** 2026-03-07
**Domain:** NixOS module documentation conventions, inline comment patterns
**Confidence:** HIGH

## Summary

Phase 6 is a pure documentation pass with no functional changes. All `.nix` files
in `modules/` and `hosts/nixos-base/` must receive structured section-header
comment blocks, inline comments must explain non-obvious lines, `disko-configuration.nix`
must gain a prominent placeholder-warning block, and LUKS label cross-references
must be verified in both `boot.nix` and `disko-configuration.nix`.

The project already has a strong documentation pattern established in the `modules/system/`
files. The gap is almost entirely in `modules/services/` (five files with no headers),
the two aggregator `default.nix` files (minimal or no headers), and
`hosts/nixos-base/` (`configuration.nix` and `disko-configuration.nix` need headers;
`disko-configuration.nix` additionally needs the DOCS-03 warning block). The
`modules/system/` files are already well-commented and require only gap-fill inline
comment review.

**Primary recommendation:** Add section-header blocks to the nine files that lack
them, add the disko warning block, verify LUKS cross-references, then sweep all
files for missing inline comments on non-obvious lines.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOCS-01 | Every `.nix` file in `modules/` and `hosts/nixos-base/` opens with a section-header comment stating its purpose, defaults, and override entry points | File audit below shows exactly which files are missing headers |
| DOCS-02 | Non-obvious configuration lines throughout all modules carry an inline `#` comment explaining their purpose or security rationale | Inline comment audit below identifies gaps per file |
| DOCS-03 | `disko-configuration.nix` has a prominent warning block at the top listing all placeholder values that must be replaced before use (`/dev/DISK`, `SIZE_RAM * 2`) | `disko-configuration.nix` currently has zero header — this is the largest single gap |
| DOCS-04 | The LUKS label string `NIXLUKS` is present in both `disko-configuration.nix` and `boot.nix` with a comment in each file explicitly cross-referencing the other file | `boot.nix` already has the cross-reference; `disko-configuration.nix` has only an inline comment, not an explicit named cross-reference in the header |
</phase_requirements>

## Standard Stack

This phase uses no new libraries. The work is text editing of existing `.nix` files.

### Core
| Tool | Purpose | Notes |
|------|---------|-------|
| Text editor / Write tool | Adding comment blocks to `.nix` files | No new Nix dependencies |
| `nix flake check` / `nixos-rebuild build` | Verify comments did not accidentally break syntax | Run after each file edit |

### Nix comment syntax
```nix
# Single-line comment — the only comment form in Nix.
# Multi-line comments are just consecutive # lines.
# There is no block comment syntax (/* */ is valid but uncommon; avoid for headers).
```

**Confidence:** HIGH — Nix has no block comment construct. All documentation is
`#`-prefixed lines. This is consistent across every existing module in this project.

## Architecture Patterns

### Established Header Format (from modules/system/ — use this as the canonical template)

Every file in `modules/system/` that was created in Phases 3-4 follows this exact
structure. Phase 6 must replicate it for all remaining files:

```nix
# <relative/path/to/file.nix>
#
# Purpose  : <one-line statement of what this file configures>
# Options  : <nerv.* options exposed, or "None — fully opaque">
# Defaults : <key defaults, or "N/A">
# Override : <how a host escapes the defaults, typically lib.mkForce>
# Note     : <optional — cross-references, caveats, import order constraints>
```

Fields used conditionally:
- `Note` — only when there is something non-obvious (e.g. LUKS sync requirement,
  import ordering constraint, platform restriction)
- `Defaults` — omit if the file is an aggregator with no options
- `Override` — omit if the file has no user-overridable settings

### DOCS-03 Warning Block Format (for disko-configuration.nix)

The warning block must be prominent (visually distinct, at the very top before
any Nix expression), and must enumerate all placeholder values with replacement
instructions:

```nix
# hosts/nixos-base/disko-configuration.nix
#
# !! WARNING — PLACEHOLDER VALUES MUST BE REPLACED BEFORE USE !!
#
#   /dev/DISK        Replace with the actual target disk, e.g. "/dev/nvme0n1"
#                    Find with: lsblk -d -o NAME,SIZE,MODEL
#   SIZE_RAM * 2     Replace with a concrete size, e.g. "16G" (2× physical RAM).
#                    Find RAM size with: free -h
#
# Purpose  : Disko declarative disk partitioning — GPT, EFI, LUKS-on-LVM layout.
# Options  : None — edit this file directly for the target machine.
# LUKS     : NIXLUKS label must stay in sync with modules/system/boot.nix
#            and modules/system/secureboot.nix.
```

### DOCS-04 LUKS Cross-Reference Pattern

The requirement is that the label `NIXLUKS` appears in both files with an explicit
comment naming the other file. Current state:

| File | Current state | Gap |
|------|--------------|-----|
| `modules/system/boot.nix` | Line 8 in header: `# LUKS : NIXLUKS label must stay in sync with hosts/nixos-base/disko-configuration.nix and modules/system/secureboot.nix.` and inline on line 20: `# must match disko-configuration.nix and secureboot.nix` | None — fully compliant |
| `hosts/nixos-base/disko-configuration.nix` | Line 26 inline: `# NIXLUKS label — must stay in sync with modules/system/boot.nix and modules/system/secureboot.nix` | The header section-level cross-reference is missing (the file has no header at all). Adding the DOCS-03 warning block (which includes the LUKS line) resolves DOCS-04 for this file simultaneously. |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Comment formatting linter | Custom script | Manual review — there is no NixOS-specific comment linter; the established pattern is the standard |
| Automated comment injection | sed/awk scripts | Direct file edits — comments are content, not boilerplate; each header requires human judgment |

## File Audit: Documentation Status

### Files requiring section-header blocks (DOCS-01 gap)

| File | Current state | Required action |
|------|--------------|-----------------|
| `modules/services/openssh.nix` | No header | Add full header block |
| `modules/services/pipewire.nix` | No header | Add full header block |
| `modules/services/bluetooth.nix` | No header | Add full header block |
| `modules/services/printing.nix` | No header | Add full header block |
| `modules/services/zsh.nix` | No header | Add full header block |
| `modules/services/default.nix` | No header | Add aggregator header (Purpose only, no Options) |
| `modules/system/default.nix` | Minimal one-line comment — not structured | Replace with full aggregator header |
| `modules/default.nix` | Minimal comment — not structured | Replace with full aggregator header |
| `hosts/nixos-base/configuration.nix` | No header | Add host-file header (purpose + key nerv.* entry points) |
| `hosts/nixos-base/disko-configuration.nix` | No header | Add DOCS-03 warning block + purpose + LUKS cross-reference |
| `hosts/nixos-base/hardware-configuration.nix` | Inline placeholder comment only | Add structured header explaining placeholder convention |

### Files already compliant with DOCS-01

| File | Header quality |
|------|---------------|
| `modules/system/boot.nix` | Full header with LUKS cross-reference |
| `modules/system/identity.nix` | Full header with options, defaults, override |
| `modules/system/hardware.nix` | Full header with options, defaults, override, note |
| `modules/system/kernel.nix` | Full header with opaque declaration |
| `modules/system/security.nix` | Full header with opaque declaration |
| `modules/system/nix.nix` | Full header with opaque declaration |
| `modules/system/impermanence.nix` | Full header with options, defaults, override |
| `modules/system/secureboot.nix` | Full header with LUKS cross-reference, import ordering note |
| `home/default.nix` | Full header with convention, options, note, user prerequisite |

### Inline comment gaps by file (DOCS-02)

Files requiring inline comment additions:

**`modules/services/openssh.nix`** (non-obvious lines to comment):
- `openFirewall = true` — clarify that fail2ban owns banning but the firewall hole is still needed
- `PermitRootLogin = "no"` — security rationale
- `bantime-increment` block — explain the exponential backoff strategy
- `overalljails = true` — explain cross-jail aggregation

**`modules/services/pipewire.nix`** — already has inline comments throughout; review only

**`modules/services/bluetooth.nix`** — already has inline comments; review only

**`modules/services/printing.nix`** — already has inline comments; review only

**`modules/services/zsh.nix`** — already has inline comments; review only

**`modules/system/default.nix`** — aggregator only; no inline comments needed beyond the header

**`modules/services/default.nix`** — aggregator only; no inline comments needed beyond the header

**`hosts/nixos-base/configuration.nix`** — partially commented; review each `nerv.*` block for clarity

**`hosts/nixos-base/disko-configuration.nix`** — has inline comment on NIXLUKS line; rest is fairly self-evident; `passwordFile` line should note it is install-script-seeded

### DOCS-03 and DOCS-04 status

- **DOCS-03** (disko warning block): **NOT MET** — `disko-configuration.nix` has no header at all. The prominent warning block is the highest-priority single addition in this phase.
- **DOCS-04** (LUKS cross-reference in both files): **PARTIALLY MET** — `boot.nix` is fully compliant. `disko-configuration.nix` has only an inline comment, no header-level cross-reference. Adding the DOCS-03 warning block that includes the LUKS line resolves both DOCS-03 and the `disko-configuration.nix` side of DOCS-04 in a single edit.

## Common Pitfalls

### Pitfall 1: Breaking Nix syntax with comment placement
**What goes wrong:** A comment placed between a function argument and the `{`, or inside a string, causes a parse error.
**Why it happens:** Nix's lexer is sensitive to comment position in a few contexts (e.g., inside `''...''` multi-line strings).
**How to avoid:** Always place header comments before the opening `{` or `let` keyword; never inside string literals; run `nix-instantiate --parse <file>` or `nix flake check` after editing.
**Warning signs:** `error: syntax error, unexpected...` during evaluation.

### Pitfall 2: Editing the wrong module tree
**What goes wrong:** Updating comments in the legacy flat `modules/*.nix` files (e.g. `modules/openssh.nix`, `modules/hardware.nix`) instead of the active `modules/system/` and `modules/services/` files.
**Why it happens:** The repo has both old flat modules and new structured modules. The flat ones are superseded but still present.
**How to avoid:** DOCS-01 scope is `modules/system/`, `modules/services/`, and `hosts/nixos-base/` — NOT the root-level `modules/*.nix` legacy files. Confirm the file path before every edit.

### Pitfall 3: Missing the aggregator default.nix files
**What goes wrong:** Only patching service/system module files, forgetting `modules/default.nix`, `modules/system/default.nix`, and `modules/services/default.nix`.
**Why it happens:** Aggregators feel like boilerplate but they are `.nix` files in `modules/` scope and must comply with DOCS-01.
**How to avoid:** Use the file audit table above as a checklist; mark each file done explicitly.

### Pitfall 4: Adding a header to hardware-configuration.nix that is too specific
**What goes wrong:** Writing a header describing real hardware — but this file is a placeholder.
**Why it happens:** The file currently has a single inline comment; a new header might over-specify.
**How to avoid:** The header should explain the placeholder convention, not any real hardware, since the file is replaced on target machines. Keep it brief: Purpose = placeholder; Override = run `nixos-generate-config --show-hardware-config` on the target machine.

### Pitfall 5: Omitting the disko warning block entirely
**What goes wrong:** Adding a plain purpose-style header to `disko-configuration.nix` without the prominent `!! WARNING !!` block.
**Why it happens:** The DOCS-01 and DOCS-03 requirements overlap on this file; a writer might satisfy DOCS-01 and miss DOCS-03.
**How to avoid:** Treat `disko-configuration.nix` as requiring TWO additions: the warning block (DOCS-03) and then the standard purpose header lines; they combine into one header block at the top of the file.

## Code Examples

### Canonical header — opaque module (no user options)
```nix
# modules/services/openssh.nix
#
# Purpose  : SSH daemon hardened with endlessh tarpit and fail2ban.
# Options  : nerv.openssh.enable, nerv.openssh.port, nerv.openssh.tarpitPort,
#            nerv.openssh.allowUsers, nerv.openssh.passwordAuth,
#            nerv.openssh.kbdInteractiveAuth
# Defaults : enable = false; port = 2222; tarpitPort = 22; allowUsers = []
#            passwordAuth = false; kbdInteractiveAuth = false
# Override : lib.mkForce on any services.openssh.* or services.fail2ban.* setting.
# Note     : Port 22 is reserved for the endlessh tarpit. Connect with ssh -p <port>.
#            allowUsers guard: empty list means "all users" in sshd — never emit
#            AllowUsers when the list is empty (lib.optionalAttrs guard enforces this).
```

### Canonical header — enable-only service module
```nix
# modules/services/pipewire.nix
#
# Purpose  : PipeWire audio stack with ALSA, PulseAudio compat, and AirPlay sink.
# Options  : nerv.audio.enable (default: false)
# Defaults : disabled — no audio stack unless explicitly enabled.
# Override : lib.mkForce on any services.pipewire.* setting.
# Note     : Reduced-latency defaults (1024/48000 ≈ 21ms). Increase quantum
#            if crackling occurs. For audio production, lower to 64 or 32.
```

### Canonical header — aggregator (no options)
```nix
# modules/services/default.nix
#
# Purpose  : Aggregates all nerv service modules.
# Modules  : openssh, pipewire, bluetooth, printing, zsh
# Note     : All modules are disabled by default. Enable via nerv.*.<module>.enable.
```

### Canonical header — host configuration file
```nix
# hosts/nixos-base/configuration.nix
#
# Purpose  : Machine-specific configuration for the nixos-base host.
# Role     : Declares nerv.* options for this machine; does not define module logic.
# Entry    : nerv.hostname, nerv.locale.*, nerv.primaryUser, nerv.hardware.*,
#            nerv.openssh.*, nerv.audio.enable, nerv.bluetooth.enable,
#            nerv.printing.enable, nerv.zsh.enable, nerv.home.*
# Override : Edit this file directly. This is the user-facing configuration surface.
# Note     : fileSystems use lib.mkForce to override Disko-generated mounts.
#            Labels (NIXBOOT, NIXROOT, NIXSWAP) must stay in sync with
#            hosts/nixos-base/disko-configuration.nix.
```

### DOCS-03 warning block + DOCS-04 LUKS cross-reference (disko-configuration.nix)
```nix
# hosts/nixos-base/disko-configuration.nix
#
# !! WARNING — PLACEHOLDER VALUES MUST BE REPLACED BEFORE USE !!
#
#   /dev/DISK      Replace with the actual target disk, e.g. "/dev/nvme0n1"
#                  Find with: lsblk -d -o NAME,SIZE,MODEL
#   SIZE_RAM * 2   Replace with a concrete size, e.g. "16G" (2× physical RAM).
#                  Find RAM size with: free -h
#
# Purpose  : Disko declarative disk layout — GPT / EFI / LUKS-on-LVM.
# Options  : None — edit this file directly for the target machine.
# LUKS     : NIXLUKS label must stay in sync with modules/system/boot.nix
#            and modules/system/secureboot.nix.
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (documentation-only phase) |
| Config file | N/A |
| Quick run command | `nix-instantiate --parse <file>` for syntax check |
| Full suite command | `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DOCS-01 | Every module file has a section-header comment | manual | grep-based spot check | N/A |
| DOCS-02 | Non-obvious lines have inline comments | manual | code review | N/A |
| DOCS-03 | disko-configuration.nix has prominent warning block | manual | `head -20 hosts/nixos-base/disko-configuration.nix` | N/A |
| DOCS-04 | NIXLUKS label cross-referenced in both files | manual | `grep -n NIXLUKS modules/system/boot.nix hosts/nixos-base/disko-configuration.nix` | N/A |

All four DOCS requirements are human-verifiable by reading the files. There is no
automated test that enforces comment presence. The build check (`nixos-rebuild build`)
validates that no comment edit introduced a syntax error — this is the primary
automated gate.

### Sampling Rate
- **Per file edit:** `nix-instantiate --parse <edited-file>` to catch syntax errors immediately
- **Per wave merge:** `nixos-rebuild build --flake /home/demon/Developments/test-nerv.nixos#nixos-base`
- **Phase gate:** Full build green + manual review checklist completed before `/gsd:verify-work`

### Wave 0 Gaps
None — existing build infrastructure covers all phase requirements. No new test files needed.

## Open Questions

1. **Scope of `modules/*.nix` legacy files**
   - What we know: The repo contains legacy flat modules (`modules/openssh.nix`, `modules/hardware.nix`, etc.) that are superseded by the structured `modules/system/` and `modules/services/` equivalents.
   - What's unclear: The REQUIREMENTS.md wording says `modules/` (which would include the legacy files), but the ROADMAP success criterion says "Every `.nix` file in `modules/` and `hosts/nixos-base/`."
   - Recommendation: **Exclude** legacy flat files from DOCS-01 scope. They are superseded and will be deleted in a future cleanup. Documenting them would be wasted effort. The intent of "modules/" in the requirements is the active `modules/system/` and `modules/services/` subtrees. Confirm with the planner.

2. **`flake.nix` and `server/` files**
   - What we know: `flake.nix` and `server/configuration.nix`, `server/disko-configuration.nix` exist at the repo root but are not in `modules/` or `hosts/nixos-base/`.
   - What's unclear: Whether these fall in scope for DOCS-01.
   - Recommendation: **Exclude** — they are explicitly outside the stated scope. `flake.nix` already has inline comments throughout. `server/` appears to be a secondary configuration not part of the primary module library.

## Sources

### Primary (HIGH confidence)
- Direct read of all 21 `.nix` files in scope — documentation status is fact, not inference
- `REQUIREMENTS.md` and `ROADMAP.md` — requirement text is authoritative

### Secondary (MEDIUM confidence)
- Nix language specification — `#` is the only comment delimiter; `/* */` is valid but unused in this codebase

## Metadata

**Confidence breakdown:**
- File audit (which files need headers): HIGH — read every file directly
- Header format pattern: HIGH — derived from 9 existing compliant files in the codebase
- Inline comment gaps: MEDIUM — subjective judgment of what counts as "non-obvious"
- DOCS-03/DOCS-04 compliance gaps: HIGH — verified by file content inspection

**Research date:** 2026-03-07
**Valid until:** Until any new `.nix` file is added to `modules/` or `hosts/nixos-base/`; the file list is exhaustive as of this date.
