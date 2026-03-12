---
phase: 11-impermanence-btrfs-mode
verified: 2026-03-10T00:00:00Z
status: human_needed
score: 4/5 must-haves verified (5th requires nix eval on NixOS target)
re_verification: false
human_verification:
  - test: "Run nix flake check on a NixOS target where hostProfile and vmProfile have been manually patched to mode = \"btrfs\" (or mode = \"full\") to remove the expected enum-type error"
    expected: "nix flake check exits 0 with no evaluation errors; serverProfile (mode = \"full\") continues to evaluate correctly"
    why_human: "nix is not installed on the dev machine; flake.nix still declares mode = \"minimal\" in hostProfile and vmProfile (intentional breaking change; Phase 12 owns the fix) so the full check cannot pass until Phase 12"
  - test: "On a NixOS target with hostProfile using mode = \"btrfs\": run nix eval .#nixosConfigurations.host.config.environment.persistence"
    expected: "Output includes directories [\"/var/lib\" \"/etc/nixos\"] and files [/etc/machine-id, four SSH host key paths]; /var/log is absent"
    why_human: "nix eval unavailable on dev machine"
  - test: "On a NixOS target: run nix eval .#nixosConfigurations.host.config.fileSystems.\"/persist\".neededForBoot"
    expected: "Returns true"
    why_human: "nix eval unavailable on dev machine"
---

# Phase 11: Impermanence BTRFS Mode Verification Report

**Phase Goal:** Setting nerv.impermanence.mode = "btrfs" activates environment.persistence for the desktop profile without a tmpfs /; /persist (the @persist subvolume) is marked neededForBoot so bind-mounts are available before services start; /var/log is excluded from persistence (handled by @log subvolume)
**Verified:** 2026-03-10
**Status:** human_needed (4/5 truths verified statically; truth 5 requires nix eval on NixOS target)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Setting nerv.impermanence.mode = "btrfs" activates environment.persistence."/persist" with /var/lib, /etc/nixos, and the five SSH/machine-id files | VERIFIED | Lines 144–159: btrfs lib.mkIf block contains `environment.persistence."${cfg.persistPath}"` with `hideMounts = true`, directories `["/var/lib" "/etc/nixos"]`, and all five files |
| 2 | /var/log is absent from environment.persistence."/persist".directories in btrfs mode | VERIFIED | Line 119: /var/log appears only in the full-mode block. Lines 149–150: a comment inside the btrfs block explicitly documents the omission. No executable /var/log entry in btrfs directories list |
| 3 | fileSystems."/persist".neededForBoot evaluates to true when mode = "btrfs" | VERIFIED | Line 138: `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;` is the first statement inside the btrfs lib.mkIf block |
| 4 | The mode enum accepts only "btrfs" or "full" — "minimal" is gone and there is no default | VERIFIED | Line 45: `type = lib.types.enum [ "btrfs" "full" ]`. No `default` attribute on the mode option. `grep "minimal" impermanence.nix` returns no matches |
| 5 | nix flake check passes with no evaluation errors after the rewrite | HUMAN NEEDED | nix unavailable on dev machine. flake.nix profiles hostProfile (line 42) and vmProfile (line 71) still declare `mode = "minimal"` — intentional breaking change per plan; Phase 12 owns the fix. serverProfile (line 57, mode = "full") is unaffected |

**Score:** 4/5 truths verified statically; truth 5 blocked by nix tooling unavailability and expected pre-Phase-12 breakage

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `modules/system/impermanence.nix` | btrfs impermanence mode + minimal-mode removal | VERIFIED | File is 177 lines, substantive, not a stub. Contains lib.mkMerge with three entries (common at line 81, full at line 103, btrfs at line 134). Contains `lib.mkIf (cfg.mode == "btrfs")` at line 134 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `modules/system/impermanence.nix` | `environment.persistence."/persist"` | `lib.mkIf (cfg.mode == "btrfs")` block | WIRED | Line 134: guard condition `cfg.mode == "btrfs"`. Line 144: `environment.persistence."${cfg.persistPath}"` attrset with directories and files fully populated |
| `modules/system/impermanence.nix` | `fileSystems."/persist".neededForBoot` | `lib.mkDefault true` inside btrfs block | WIRED | Line 138: `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;` is inside the btrfs lib.mkIf block, not the full block |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PERSIST-01 | 11-01-PLAN.md | mode = "btrfs" activates environment.persistence."/persist" without tmpfs /; declares machine-id, SSH host keys, /var/lib/nixos, /var/lib/systemd, /etc/nixos; /var/log excluded | SATISFIED with design delta | Implementation uses `/var/lib` (superset) instead of `/var/lib/nixos` + `/var/lib/systemd` individually. The PLAN must_haves and success_criteria explicitly adopt `/var/lib` as a deliberate design decision (key-decisions: "/var/lib as single broad entry covers all service state"). `/var/lib` is a strict superset that satisfies the requirement functionally. /var/log is absent from btrfs block (line 149 comment only). All five files present (lines 153–158) |
| PERSIST-02 | 11-01-PLAN.md | /persist has neededForBoot = true when mode = "btrfs" | SATISFIED | Line 138: `fileSystems."${cfg.persistPath}".neededForBoot = lib.mkDefault true;` is unconditionally set inside the btrfs lib.mkIf block |

**Orphaned requirements check:** REQUIREMENTS.md maps PERSIST-01 and PERSIST-02 to Phase 11 at lines 124–125. Both are claimed by 11-01-PLAN.md. No orphaned requirements.

**PERSIST-01 design delta note:** REQUIREMENTS.md text names `/var/lib/nixos` and `/var/lib/systemd` explicitly. The ROADMAP Phase 11 Success Criteria #1 names the same explicit paths. However, the PLAN (which is the execution contract for this phase) overrides this at must_haves truth #1 and success_criteria (line 270): "directories [/var/lib, /etc/nixos]". The SUMMARY confirms this as a deliberate key-decision: "/var/lib as single broad entry — covers all service state (nixos uid/gid allocations, systemd timers, sbctl keys, BT, NM, CUPS state) in one entry — avoids a long explicit list that requires maintenance." The requirement is satisfied functionally; the REQUIREMENTS.md and ROADMAP wording predates the Phase 11 planning decision. If strict literal compliance with REQUIREMENTS.md is needed, the requirements text should be updated by Phase 12 or a follow-up doc sweep.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | — | — | — |

Scanned for: TODO/FIXME/XXX/HACK/PLACEHOLDER comments, return null, return {}, return [], empty handlers. None found in `modules/system/impermanence.nix`.

### Human Verification Required

#### 1. nix flake check on NixOS target

**Test:** On a NixOS machine, patch `flake.nix` hostProfile and vmProfile from `mode = "minimal"` to `mode = "btrfs"` (Phase 12 work), then run `nix flake check` from `/etc/nerv`.
**Expected:** Exit 0 with no evaluation errors. serverProfile (mode = "full") continues to pass. The impermanence module itself will evaluate correctly for both "btrfs" and "full".
**Why human:** nix is not installed on the dev machine. The flake.nix breakage is intentional (minimal no longer in enum) and is Phase 12's responsibility, not Phase 11's.

#### 2. nix eval: environment.persistence contents for btrfs host

**Test:** On a NixOS target where hostProfile has `mode = "btrfs"`, run `nix eval .#nixosConfigurations.host.config.environment.persistence`.
**Expected:** Output contains `directories = [ "/var/lib" "/etc/nixos" ]` and `files = [ "/etc/machine-id" "/etc/ssh/ssh_host_ed25519_key" "/etc/ssh/ssh_host_ed25519_key.pub" "/etc/ssh/ssh_host_rsa_key" "/etc/ssh/ssh_host_rsa_key.pub" ]`. `/var/log` must be absent from directories.
**Why human:** nix eval unavailable on dev machine.

#### 3. nix eval: fileSystems."/persist".neededForBoot

**Test:** On a NixOS target where hostProfile has `mode = "btrfs"`, run `nix eval .#nixosConfigurations.host.config.fileSystems."/persist".neededForBoot`.
**Expected:** Returns `true`.
**Why human:** nix eval unavailable on dev machine.

### Gaps Summary

No gaps blocking goal achievement. All statically verifiable truths and key links pass. The single open item (truth 5: nix flake check) is gated on:

1. nix tooling unavailability on the dev machine (consistent with Phases 8, 9, 10 precedent)
2. The intentional, documented breaking change in `flake.nix` where hostProfile and vmProfile still declare `mode = "minimal"` (now invalid enum value). This breakage is Phase 12's work scope, not Phase 11's.

The implementation in `modules/system/impermanence.nix` is structurally complete and correct. All three lib.mkMerge entries are present (common, full, btrfs), all required persistence entries are wired, the enum has no default, and minimal mode is fully removed.

**Commits delivered:**
- `89c39ec` — feat(11-01): drop minimal mode, rewrite enum to [btrfs, full], remove /tmp /var/tmp tmpfs
- `cd7136e` — feat(11-01): add btrfs lib.mkIf block with neededForBoot, environment.persistence, sbctl warning

---
_Verified: 2026-03-10_
_Verifier: Claude (gsd-verifier)_
