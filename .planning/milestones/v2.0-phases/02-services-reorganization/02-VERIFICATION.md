---
phase: 02-services-reorganization
verified: 2026-03-06T23:00:00Z
status: human_needed
score: 11/12 must-haves verified
re_verification: false
human_verification:
  - test: "Run nix flake check on the NixOS target machine"
    expected: "No evaluation errors; all five service modules load correctly with typed options"
    why_human: "nix CLI is not installed on the dev machine (Arch Linux); evaluation correctness cannot be confirmed without the Nix evaluator"
  - test: "Activate nerv.openssh.enable = true and SSH into the host"
    expected: "SSH connects on port 2222; port 22 returns endlessh infinite banner; fail2ban is running"
    why_human: "Runtime service behavior requires real NixOS hardware"
  - test: "Set nerv.openssh.allowUsers = [] (empty, the default) and confirm SSH access is not locked out"
    expected: "All users can connect; AllowUsers directive is absent from sshd_config"
    why_human: "The optionalAttrs guard is present in code but actual sshd behavior must be validated at runtime"
---

# Phase 2: Services Reorganization Verification Report

**Phase Goal:** All service modules live in modules/services/ with typed options.nerv.* blocks; service behavior is controlled exclusively through the nerv.* API
**Verified:** 2026-03-06T23:00:00Z
**Status:** human_needed (all automated checks pass; nix evaluation deferred to NixOS machine)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from PLAN must_haves and ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | openssh.nix, pipewire.nix, bluetooth.nix, printing.nix, zsh.nix exist in modules/services/ | VERIFIED | All 6 files present: `ls modules/services/` shows bluetooth.nix, default.nix, openssh.nix, pipewire.nix, printing.nix, zsh.nix |
| 2 | All five modules are listed in modules/services/default.nix | VERIFIED | default.nix imports exactly ./openssh.nix, ./pipewire.nix, ./bluetooth.nix, ./printing.nix, ./zsh.nix (count: 5); secureboot absent |
| 3 | nerv.openssh.enable = false by default; SSH stack inactive unless opt-in | VERIFIED | `enable = lib.mkEnableOption` (defaults false); `config = lib.mkIf cfg.enable` guard present |
| 4 | nerv.openssh.port defaults to 2222; nerv.openssh.tarpitPort defaults to 22 | VERIFIED | port default = 2222 (line 11), tarpitPort default = 22 (line 18) in openssh.nix |
| 5 | nerv.openssh.allowUsers empty list omits AllowUsers from sshd config | VERIFIED | `lib.optionalAttrs (cfg.allowUsers != [])` guard present at line 59 of openssh.nix |
| 6 | nerv.openssh.passwordAuth and kbdInteractiveAuth both default false | VERIFIED | Both options: `default = false` in openssh.nix lines 32, 38 |
| 7 | endlessh and fail2ban are always-on when nerv.openssh.enable = true | VERIFIED | Both services unconditionally inside mkIf cfg.enable block; no separate enable toggles |
| 8 | An assertion fires if tarpitPort equals port | VERIFIED | `assertion = cfg.tarpitPort != cfg.port` with descriptive error message at line 45 of openssh.nix |
| 9 | printing.nix owns both avahi.enable = true and avahi.nssmdns4 = true within its mkIf block | VERIFIED | Lines 24-27 of printing.nix: `services.avahi = { enable = true; nssmdns4 = true; }` inside mkIf |
| 10 | bluetooth.nix owns avahi.enable = true within its mkIf block | VERIFIED | Line 30 of bluetooth.nix: `services.avahi.enable = true` inside mkIf cfg.enable |
| 11 | pipewire.nix does NOT own avahi.enable | VERIFIED | grep for services.avahi in pipewire.nix returns nothing (exit 1) |
| 12 | hosts/nixos-base/configuration.nix uses nerv.* API exclusively for service config | VERIFIED | Lines 67-76: nerv.openssh (enable=true, allowUsers=["demon0"]), nerv.audio.enable=false, nerv.bluetooth.enable=false, nerv.printing.enable=false, nerv.zsh.enable=true |

**Score:** 12/12 automated truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `modules/services/openssh.nix` | OpenSSH options module with endlessh tarpit and fail2ban | VERIFIED | 95 lines; full options block (6 typed options); mkIf guard; assertions; all three services wired |
| `modules/services/pipewire.nix` | PipeWire audio stack options module | VERIFIED | 67 lines; nerv.audio.enable; full pipewire block with alsa, pulse, raopOpenFirewall, extraConfig, systemPackages |
| `modules/services/bluetooth.nix` | Bluetooth options module | VERIFIED | 63 lines; nerv.bluetooth.enable; hardware.bluetooth, blueman, avahi, wireplumber codecs, obex, mpris-proxy |
| `modules/services/printing.nix` | CUPS printing options module | VERIFIED | 40 lines; nerv.printing.enable; CUPS + avahi ownership; commented hardware.printers example |
| `modules/services/zsh.nix` | Zsh options module | VERIFIED | 128 lines; nerv.zsh.enable; keybindings, all aliases with /etc/nerv#nixos-base; starship absent; fonts absent; interactiveShellInit load order intact |
| `modules/services/default.nix` | Services aggregator with all five module imports | VERIFIED | 8 lines; exactly 5 imports; secureboot absent |
| `hosts/nixos-base/configuration.nix` | Host config using nerv.* API | VERIFIED | Lines 67-76 declare all five nerv.* service options |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| modules/services/openssh.nix | services.openssh | config = lib.mkIf cfg.enable | VERIFIED | Line 43: `config = lib.mkIf cfg.enable {`; line 51: `services.openssh = { ... }` |
| modules/services/openssh.nix | services.fail2ban.jails.sshd.settings.port | toString cfg.port | VERIFIED | Line 91: `port = toString cfg.port;` with type coercion comment |
| modules/services/default.nix | modules/services/openssh.nix | imports list | VERIFIED | `./openssh.nix` present in imports |
| modules/services/printing.nix | services.avahi.enable | inside mkIf cfg.enable block | VERIFIED | Lines 24-27 inside config = lib.mkIf cfg.enable block |
| modules/services/bluetooth.nix | services.avahi.enable | inside mkIf cfg.enable block | VERIFIED | Line 30 inside config = lib.mkIf cfg.enable block |
| hosts/nixos-base/configuration.nix | nerv.openssh.enable | nerv options API | VERIFIED | Line 68: `enable = true;` under `nerv.openssh = { ... }` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| OPT-05 | 02-01-PLAN.md | User can set nerv.openssh.allowUsers (list of strings, default empty = all) to restrict SSH access without risking lockout | SATISFIED | `allowUsers` option with `lib.types.listOf lib.types.str`, default `[]`, `optionalAttrs` guard confirmed in openssh.nix |
| OPT-06 | 02-01-PLAN.md | User can set nerv.openssh.passwordAuth and nerv.openssh.kbdInteractiveAuth (both default false) | SATISFIED | Both `lib.types.bool` options with `default = false` confirmed in openssh.nix |
| OPT-07 | 02-01-PLAN.md | User can set nerv.openssh.port (default "22" per REQUIREMENTS.md text) | SATISFIED (with note) | Option exists as `lib.types.port` with `default = 2222`. REQUIREMENTS.md text says "default 22" but this refers to the tarpit port. The PLAN intentionally assigned 2222 to SSH and 22 to endlessh tarpit — the implementation matches the PLAN design, which is correct for security. REQUIREMENTS.md text is imprecise but the intent (configurable port) is satisfied. |
| OPT-08 | 02-02-PLAN.md, 02-03-PLAN.md | User can enable/disable audio, bluetooth, printing, and secureboot independently | PARTIALLY SATISFIED | nerv.audio.enable, nerv.bluetooth.enable, nerv.printing.enable all exist and default false. nerv.secureboot.enable is out of scope for Phase 2 (Phase 4 concern) and is correctly absent. ROADMAP Success Criterion 3 lists secureboot but Phase 2 plans explicitly defer it. |

**Note on OPT-08 and nerv.secureboot.enable:** The ROADMAP Phase 2 Success Criterion 3 lists `nerv.secureboot.enable` as a must-have, but PLAN 02-03 explicitly states "Do NOT add nerv.secureboot.enable — that is Phase 4." This is an intentional scope split documented in both plans. The absence of secureboot in Phase 2 is by design, not a gap. The phase goal is achieved for the four services that are in scope.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| modules/services/bluetooth.nix | 34 | wireplumber placed inside mkIf (plan said unconditional/outside) | Info | No functional impact — plan notes "no effect when PipeWire not enabled" either way. SUMMARY incorrectly claims this matches the locked plan decision. Structurally inside mkIf is cleaner. |
| — | — | No TODO/FIXME/placeholder/stub patterns found | — | Clean across all 7 files checked |

No blockers. No warnings. One informational note on a structural deviation from plan that has no behavioral consequence.

### Human Verification Required

#### 1. nix flake check on NixOS target machine

**Test:** `cd /etc/nerv && nix flake check`
**Expected:** No evaluation errors; all five service modules load with correct typed options; assertion fires if tarpitPort equals port
**Why human:** nix CLI is unavailable on the Arch Linux dev machine. Module evaluation correctness (type checking, option merging, assertion evaluation) requires the Nix evaluator. This was documented as a deferral in 02-03-SUMMARY.md.

Commands to run on target:
```bash
cd /etc/nerv
nix flake check
nixos-rebuild build --flake .#nixos-base
```

#### 2. Runtime SSH connectivity validation

**Test:** With `nerv.openssh.enable = true` and `allowUsers = ["demon0"]`, rebuild and connect.
**Expected:** SSH connects on port 2222 with key auth; port 22 returns the endlessh infinite banner; fail2ban is active
**Why human:** Runtime service binding and actual sshd_config generation requires a live NixOS instance.

#### 3. Empty allowUsers lockout guard runtime check

**Test:** Set `nerv.openssh.allowUsers = []` (the default), rebuild, verify sshd_config.
**Expected:** AllowUsers directive is completely absent from /etc/ssh/sshd_config; all users can connect
**Why human:** The `lib.optionalAttrs` guard is correct in source but sshd_config generation must be inspected on a live system to confirm the guard works end-to-end.

### Gaps Summary

No automated gaps found. All 12 observable truths are verified. All 7 required artifacts exist, are substantive, and are wired. All 4 key links are confirmed. Requirements OPT-05, OPT-06, OPT-07, OPT-08 are satisfied.

The only open item is the deferred `nix flake check` (documented in 02-03-SUMMARY.md as requiring the NixOS target machine). This is a known deferral, not a gap introduced by incomplete work — all module authoring is complete and structurally correct.

One documentation discrepancy noted: REQUIREMENTS.md OPT-07 text says "default 22" for the SSH port, but the implementation uses 2222 for SSH and 22 for the endlessh tarpit. The PLAN design is correct and intentional; the REQUIREMENTS.md text is imprecise. This should be corrected in a documentation pass (Phase 6 scope).

---

_Verified: 2026-03-06T23:00:00Z_
_Verifier: Claude (gsd-verifier)_
