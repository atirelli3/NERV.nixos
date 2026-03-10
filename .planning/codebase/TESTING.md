# Testing Patterns

**Analysis Date:** 2026-03-10

## Test Framework

**Runner:**
- No automated test runner. There is no Jest, Vitest, pytest, or similar framework.
- The project uses the Nix CLI and shell commands as its validation toolchain.
- Automated test execution is integrated into a per-phase validation contract system (`.planning/phases/<phase>/VALIDATION.md`)

**Primary validation tools:**
- `nix-instantiate --parse <file.nix>` — Nix syntax check (fast, ~1s)
- `nix flake check --no-build` — full module evaluation without building (~30s)
- `nix flake check` — full evaluation + build (~60–120s)
- `nix eval .#nixosConfigurations.<name>.config.<option>` — option value spot-check
- `grep` / `shell assertions` — structural content checks on .nix files

**Run Commands:**
```bash
nix-instantiate --parse modules/system/disko.nix   # Syntax check single file
nix flake check --no-build                         # Full eval, no build (fast pass)
nix flake check                                    # Full eval + build (complete pass)
nix eval .#nixosConfigurations.host.config.nerv.disko.layout   # Option spot-check
```

**Platform note:** The development machine is macOS (Darwin). The `nix` binary is unavailable in this environment. All `nix-*` commands must run on a NixOS target machine. Shell-based checks (`grep`, `ls`, `wc -l`) run locally on macOS.

## Validation Contract System

Each phase has a `VALIDATION.md` file at `.planning/phases/<phase>-<slug>/VALIDATION.md`.

**Frontmatter fields:**
```yaml
---
phase: 9
slug: btrfs-disko-layout
status: complete
nyquist_compliant: false
wave_0_complete: true
created: 2026-03-09
---
```

**Per-Task Verification Map** — every task maps to a testable assertion:

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 9-01-02 | 01 | 1 | DISKO-01 | smoke | `grep -c '"/@"' modules/system/disko.nix` (expect ≥1) | ✅ | ✅ green |

Status values: `⬜ pending`, `✅ green`, `❌ red`, `⚠️ flaky`, `→ manual-only`

**Nyquist compliance:** A phase is `nyquist_compliant: true` when no 3 consecutive tasks lack an automated verification command. This ensures sampling density — automated checks bracket every logical unit of work.

## Test Types

**smoke:**
- Fastest feedback signal — file existence or content presence
- Example: `ls modules/system/default.nix modules/services/default.nix`
- Example: `grep -c '"/@"' modules/system/disko.nix` (expect ≥1)
- Used after every task commit

**grep / shell:**
- Structural content assertions via `grep`, `wc -l`, `ls`
- Example: `grep -c 'space_cache=v2' modules/system/disko.nix` (expect 5)
- Example: `grep -q 'nerv.disko.layout = "btrfs"' flake.nix`
- Runs instantly on macOS dev machine; no nix required

**integration:**
- Full flake evaluation or rebuild
- Example: `nix flake check --no-build`, `nix flake check`
- Requires NixOS target machine
- Run after each plan wave, not each task

**manual-only:**
- Behaviors that require a real boot, a VM, or external state
- Documented in the `Manual-Only Verifications` table with explicit test instructions
- Examples: "BTRFS subvolumes actually created at install time", "full impermanence activates correctly on server"

## Validation File Structure

```
.planning/phases/<N>-<slug>/
├── <N>-VALIDATION.md        # Validation contract (test types, commands, per-task map)
├── <N>-VERIFICATION.md      # Execution results (truths confirmed, pass/fail counts)
├── <N>-01-PLAN.md           # Task plan for plan wave 01
├── <N>-01-SUMMARY.md        # Execution summary for plan wave 01
└── ...
```

**VERIFICATION.md** records post-execution results with explicit truth statements:
- Lists each requirement and whether it was confirmed
- Reports overall pass/fail ratio (e.g., "7/7 truths")
- Documents any deferred checks and why

## Wave-Based Execution Model

Phases are divided into plan waves (01, 02, 03...). Each wave:
1. Has a PLAN.md defining tasks
2. Has a SUMMARY.md recording what was done
3. Corresponds to rows in the Per-Task Verification Map

**Wave 0** is special: covers test infrastructure setup (creating config files, installing frameworks). For this codebase Wave 0 always concludes "No new test infrastructure required — validation uses nix CLI which is the project's native toolchain."

## Sampling Rate Convention

From the validation contracts:

```
- After every task commit:   Run the automated command for that task
- After every plan wave:     Run nix flake check (or equivalent full-suite command)
- Before /gsd:verify-work:  Full suite must be green
- Max feedback latency:      10–120 seconds depending on command type
```

## Assertions as Inline Tests

The Nix module system's `assertions` mechanism functions as runtime validation at `nixos-rebuild` time:

```nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

These fire on every `nixos-rebuild switch/boot/test` and serve as integration tests for module invariants. All assertions are in production modules — no separate test module files exist.

**Assertion locations:**
- `modules/services/openssh.nix`: port collision guard
- `modules/system/identity.nix`: non-empty hostname guard
- `modules/system/impermanence.nix`: sbctl path + tmpfs wipe guard (conditional on `nerv.secureboot.enable`)

**Warnings as soft assertions:**
```nix
warnings =
  lib.optionals (config.nerv.secureboot.enable && !sbctlCovered)
    [ "nerv: secureboot is enabled but /var/lib/sbctl is not covered by environment.persistence..." ];
```

Used when a misconfiguration is recoverable (key re-enrollment possible) vs `assertions` for unrecoverable situations (TPM wipe).

## Coverage

**Requirements:** No numeric coverage targets. Coverage is measured by requirement satisfaction: each functional requirement (e.g., `DISKO-01`, `PROF-01`) maps to at least one verification command.

**Tracked in:** `.planning/phases/<N>-<slug>/<N>-VALIDATION.md` Per-Task Verification Map

**Gaps:** Anything marked `→ manual-only` is a coverage gap requiring human verification on a target machine. These are explicitly documented with test instructions.

**Audit pattern:** Phase validations are retroactively audited and an audit section added:
```markdown
## Validation Audit 2026-03-10

| Metric | Count |
|--------|-------|
| Gaps found | 5 |
| Resolved (manual-only) | 5 |
| Escalated | 0 |
```

## What Is Not Tested

- No unit tests for individual Nix functions (helper functions in `let` bindings)
- No NixOS VM test infrastructure (`nixosTest` / `testing.nix`) — not present in this repo
- No CI pipeline (no `.github/workflows/`, no Garnix, no Hydra config)
- No linting or formatting enforcement tooling (no `nixpkgs-fmt`, `alejandra`, or `statix` config)

All functional correctness is validated manually on a NixOS target machine or deferred to `nix flake check`.

---

*Testing analysis: 2026-03-10*
