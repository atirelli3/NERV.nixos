# Testing Patterns

**Analysis Date:** 2026-03-10

## Test Framework

**Runner:** None detected.

There are no test files, no test runner configuration, and no test-related entries in the codebase. This is a NixOS configuration library, not a general-purpose software project. The codebase does not use `nixosTests`, `testers.runNixOSTest`, `pkgs.testers`, or any external test harness (Jest, pytest, etc.).

**Config files checked:** No `jest.config.*`, `vitest.config.*`, `pytest.ini`, `flake.nix#checks`, or similar were found.

## What "Testing" Means in This Codebase

Correctness is enforced at evaluation time via three mechanisms, all implemented inside the modules themselves:

### 1. NixOS Assertions (Hard Failures)

`assertions` blocks in module config cause `nixos-rebuild` to fail with a human-readable message if an invariant is violated. This is the primary correctness gate.

```nix
# modules/services/openssh.nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

```nix
# modules/system/identity.nix
assertions = [{
  assertion = config.nerv.hostname != "";
  message   = "nerv.hostname must not be empty string.";
}];
```

```nix
# modules/system/impermanence.nix
assertions = lib.optional config.nerv.secureboot.enable {
  assertion = !(lib.any isSbctlPath allPaths);
  message = "nerv: /var/lib/sbctl is in impermanence tmpfs paths — this would wipe Secure Boot keys on every reboot. ...";
};
```

Files using assertions: `modules/services/openssh.nix`, `modules/system/identity.nix`, `modules/system/impermanence.nix`.

### 2. NixOS Warnings (Soft Failures)

`warnings` blocks emit a message during `nixos-rebuild` without blocking the build. Used for recoverable misconfigurations where the system remains functional but the operator should act.

```nix
# modules/system/impermanence.nix
warnings =
  lib.optionals (config.nerv.secureboot.enable && !sbctlCovered)
    [ "nerv: secureboot is enabled but /var/lib/sbctl is not covered by environment.persistence in btrfs mode — sbctl keys will be lost on rollback." ];
```

The docstring in `impermanence.nix` explicitly explains the choice between assertion and warning:
> Using lib.warn (not assertion) — preserves nix flake check during multi-step migrations; missing sbctl persistence loses keys on next rollback but is recoverable via re-enrollment, unlike the IMPL-02 scenario (tmpfs wipe) which uses a hard assertion.

File: `modules/system/impermanence.nix` lines 165–176.

### 3. Nix Type System

`lib.mkOption` with explicit `type` constraints catches type errors at evaluation. Enum constraints replace runtime validation for options with a fixed set of valid values:

```nix
type = lib.types.enum [ "btrfs" "lvm" ]
type = lib.types.enum [ "amd" "intel" "other" ]
type = lib.types.enum [ "amd" "nvidia" "intel" "none" ]
type = lib.types.port
type = lib.types.listOf lib.types.str
type = lib.types.attrsOf (lib.types.attrsOf lib.types.str)
```

## Manual Validation Commands

The primary "test run" for this codebase is:

```bash
# Evaluate the flake without building — catches type errors and assertion failures
nix flake check /etc/nixos

# Build and switch on target machine
sudo nixos-rebuild switch --flake /etc/nixos#host

# Build only (no switch) — validates configuration evaluates successfully
sudo nixos-rebuild build --flake /etc/nixos#host

# Test build in a temporary profile without activating
sudo nixos-rebuild test --flake /etc/nixos#host
```

Aliases defined in `modules/services/zsh.nix`: `nrs`, `nrb`, `nrt`.

## Test Coverage Gaps

**No automated test suite exists.** All validation is declarative (Nix type system + assertions) or manual (nixos-rebuild). The following areas have no automated coverage:

- **Systemd service correctness** (`secureboot-enroll-keys`, `secureboot-enroll-tpm2`, `aide-check`, `mpris-proxy`, `obex` override in `bluetooth.nix`) — these run at boot and are never exercised outside a real or VM boot.
- **BTRFS rollback service** (`boot.initrd.systemd.services.rollback` in `disko.nix`) — requires a real boot cycle to validate.
- **Disko layout generation** — `nerv.disko.layout = "btrfs"` and `"lvm"` branches are not validated against a real disk in CI.
- **Home Manager wiring** (`home/default.nix`) — the `--impure` flag requirement and `/home/<name>/home.nix` path resolution are not tested.
- **Profile composition** (`flake.nix` `hostProfile` / `serverProfile`) — no `pkgs.testers.runNixOSTest` or `nixosTests` VM tests exist.
- **Cross-module constraints** (e.g., `nerv.disko.layout = "btrfs"` required when `nerv.impermanence.mode = "btrfs"`) — documented in comments but not enforced by an assertion.

## Adding Tests

If automated testing is introduced, the standard NixOS approach is `pkgs.testers.runNixOSTest` (or `nixosTests`) in `flake.nix#checks`:

```nix
# flake.nix — example structure for future tests
checks."x86_64-linux".openssh-module = pkgs.testers.runNixOSTest {
  name = "nerv-openssh";
  nodes.machine = { ... };
  testScript = ''
    machine.wait_for_unit("sshd.service")
    ...
  '';
};
```

Test files would live in a `tests/` directory at the repo root, imported as modules in `flake.nix#checks`.

---

*Testing analysis: 2026-03-10*
