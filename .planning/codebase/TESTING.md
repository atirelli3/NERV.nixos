# Testing Patterns

**Analysis Date:** 2026-03-08

## Test Framework

**Runner:** None — no automated test suite exists in this codebase.

This is a NixOS configuration library written in the Nix expression language. It has no traditional unit test framework (no Jest, pytest, vitest, etc.). Validation is performed through a combination of:

1. **NixOS module system assertions** — `assertions` blocks inside module `config` sections catch invariant violations at `nixos-rebuild` / `nix flake check` time.
2. **Nix type system** — `lib.types.*` declarations on options provide static type checking evaluated during configuration.
3. **Manual `nixos-rebuild` testing** — the primary validation mechanism is building and switching configurations.

## Assertions (Built-in Validation)

Assertions are the closest equivalent to unit tests in this codebase. They fire at build time with a descriptive error message.

**Location:** Inside `config = lib.mkIf cfg.enable { assertions = [...]; }` blocks.

**Pattern:**
```nix
assertions = [{
  assertion = cfg.tarpitPort != cfg.port;
  message   = "nerv.openssh.tarpitPort (${toString cfg.tarpitPort}) must differ from nerv.openssh.port (${toString cfg.port}).";
}];
```

Files containing assertions:
- `modules/services/openssh.nix` — asserts tarpitPort != port
- `modules/system/identity.nix` — asserts hostname is non-empty string
- `modules/system/impermanence.nix` — asserts `/var/lib/sbctl` is not in tmpfs paths when secureboot is enabled

**Conditional assertions** use `lib.optional` so the assertion itself is only evaluated when relevant:
```nix
assertions = lib.optional config.nerv.secureboot.enable {
  assertion = !(lib.any isSbctlPath allPaths);
  message   = "nerv: /var/lib/sbctl is in impermanence tmpfs paths — ...";
};
```

## Type Validation

NixOS option types provide compile-time checking. The types used across this codebase:

| Type | Used for |
|------|----------|
| `lib.types.str` | String values (hostname, timezone, locale) |
| `lib.types.port` | Network ports (openssh.port, openssh.tarpitPort) |
| `lib.types.bool` | Boolean flags (passwordAuth, kbdInteractiveAuth) |
| `lib.types.listOf lib.types.str` | User lists, allow lists, extraDirs |
| `lib.types.enum [ "amd" "intel" "other" ]` | Constrained string choices |
| `lib.types.attrsOf (lib.types.attrsOf lib.types.str)` | Per-user path/size maps (impermanence.users) |

Type errors surface at `nix flake check` or `nixos-rebuild` time before any deployment occurs.

## How to Validate the Configuration

There is no `npm test` or equivalent. Validation commands:

```bash
# Static evaluation — checks types, assertions, and option definitions
nix flake check /etc/nixos

# Build without switching — catches runtime configuration errors
sudo nixos-rebuild build --flake /etc/nixos#host

# Build and test without activating
sudo nixos-rebuild test --flake /etc/nixos#host

# Full switch — apply to running system
sudo nixos-rebuild switch --flake /etc/nixos#host

# Zsh aliases provided by the codebase itself (when nerv.zsh.enable = true):
nrs   # nixos-rebuild switch --flake /etc/nixos#host
nrb   # nixos-rebuild boot   --flake /etc/nixos#host
nrt   # nixos-rebuild test   --flake /etc/nixos#host
```

## NixOS VM Testing (Available, Not Implemented)

NixOS provides `nixpkgs.lib.nixos.runTests` and `nixpkgs.lib.nixosSystem` with `config.system.build.vm` for integration testing in a QEMU VM. This is not currently used in the codebase. If added, the pattern would be:

```nix
# In flake.nix outputs:
checks.x86_64-linux.module-test = nixpkgs.lib.nixos.runTests {
  imports = [ self.nixosModules.default ];
  # ... test configuration and assertions
};
```

## Test Coverage

**What is validated at build time:**
- Port conflict between SSH daemon and endlessh tarpit (`openssh.nix`)
- Non-empty hostname requirement (`identity.nix`)
- Secure Boot + impermanence sbctl path safety (`impermanence.nix`)
- All option type constraints (via NixOS type system, all modules)
- Import order for `secureboot.nix` (by convention + comment, not automated)

**What is NOT validated automatically:**
- Cross-file label consistency (`NIXLUKS` label appears in `boot.nix`, `disko-configuration.nix`, `secureboot.nix` — kept in sync by comment only)
- Hardware-specific correctness (GPU/CPU driver selection)
- Runtime behavior of systemd services (secureboot enrollment scripts, AIDE timer, mpris-proxy)
- Actual disk layout matches disko configuration
- Home Manager user configurations (`~/home.nix` contents are outside the flake boundary)

**Coverage gaps that carry risk:**
- `hosts/configuration.nix` contains literal `"PLACEHOLDER"` strings — no assertion validates these are replaced before deployment. A `nixos-rebuild switch` with `nerv.hostname = "PLACEHOLDER"` will succeed at the Nix level.
- The two-boot secureboot enrollment sequence (`secureboot.nix`) is state-machine logic in shell scripts with no automated verification.

## Adding New Assertions

When adding a new module option that has interdependencies or invariants, add an assertion. Follow this pattern in `modules/services/<name>.nix` or `modules/system/<name>.nix`:

```nix
config = lib.mkIf cfg.enable {
  assertions = [{
    assertion = <bool expression>;
    message   = "<descriptive message with ${interpolated} actual values>";
  }];
  # rest of config...
};
```

For assertions that should only fire when another nerv feature is also enabled, use `lib.optional`:

```nix
assertions = lib.optional config.nerv.<other-feature>.enable {
  assertion = <bool>;
  message   = "...";
};
```

---

*Testing analysis: 2026-03-08*
