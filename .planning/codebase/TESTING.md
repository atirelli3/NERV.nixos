# Testing Patterns

**Analysis Date:** 2026-03-06

## Test Framework

**Runner:** None detected.

This is a pure NixOS configuration codebase written in the Nix expression language. There are no unit test files, no test runner configuration, and no test dependencies. The project contains only `.nix` declarative configuration files.

**Config files searched:** No `jest.config.*`, `vitest.config.*`, `pytest.ini`, `*.test.*`, `*.spec.*` found anywhere in the repository.

## Validation Approach

NixOS configurations are validated at build/evaluation time by the Nix evaluator itself. The primary "test" mechanism is:

```bash
# Evaluate the flake without building — catches Nix syntax errors and type errors
nix flake check /path/to/flake

# Build a configuration to verify it assembles correctly
nixos-rebuild build --flake .#nixos-base

# Test the configuration in a VM (does not apply to real hardware)
nixos-rebuild build-vm --flake .#nixos-base
```

These commands are not scripted anywhere in the repository; they are manual operations.

## Idempotency Guards in Systemd Scripts

Imperative logic inside `systemd.services.*.script` blocks implements a form of integration testing via guard files. Before any destructive action, scripts check for a sentinel file and exit early if the action has already been performed:

```bash
# Pattern used in modules/secureboot.nix
if [ -f /var/lib/secureboot-keys-enrolled ]; then
  echo "secureboot [1/2]: already done, skipping"
  exit 0
fi
```

This pattern appears in:
- `modules/secureboot.nix` — `secureboot-enroll-keys` service (line 67) and `secureboot-enroll-tpm2` service (line 101)
- `.template/configuration.nix` — `secureboot-setup` service (line 229)

## Scheduled Integrity Verification

`modules/security.nix` defines a systemd timer that runs AIDE (file integrity monitoring) daily and exits non-zero when changes are detected. This functions as an automated runtime correctness check for system file integrity:

```nix
# modules/security.nix lines 96-113
systemd.services.aide-check = {
  description = "AIDE file integrity check";
  serviceConfig = {
    Type            = "oneshot";
    ExecStart       = "${pkgs.aide}/bin/aide --check --config /etc/aide.conf";
    SuccessExitStatus = [ 0 1 ]; # exit 1 means changes detected, not a unit failure
  };
};

systemd.timers.aide-check = {
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
};
```

## Manual Verification Tools

The following packages are installed for manual system health checks:
- `lynis` — system hardening auditor; run with `sudo lynis audit system`
- `aide` — file integrity monitor; verify with `aide --check`
- `sbctl` — Secure Boot key management and status; verify with `sbctl status`
- `tpm2-tools` — TPM2 chip verification

These are declared in `modules/security.nix` (lines 49–52) and `modules/secureboot.nix` (lines 134–139).

## No Automated Test Suite

**There are no:**
- Unit tests for individual Nix modules
- NixOS VM integration tests (NixOS supports these via `nixosTest`, but none are defined here)
- CI pipeline configuration (no `.github/workflows/`, `.gitlab-ci.yml`, or similar)
- Pre-commit hooks that run tests
- Coverage requirements

## Recommended NixOS Testing Approach

If tests are added to this codebase, the standard NixOS pattern is `pkgs.nixosTest` / `lib.nixosTest`, which boots a VM and runs Python assertions against it. This would be placed in a `tests/` directory and exposed via the flake `checks` output:

```nix
# Hypothetical addition to base/flake.nix
checks.x86_64-linux.my-test = nixpkgs.lib.nixosTest {
  name = "my-test";
  nodes.machine = { ... };  # NixOS configuration
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl is-active sshd")
  '';
};
```

No such tests exist currently.

---

*Testing analysis: 2026-03-06*
