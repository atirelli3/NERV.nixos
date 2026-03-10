# Module: Impermanence

**File:** `modules/system/impermanence.nix`

Two persistence strategies: BTRFS rollback (desktop) and tmpfs root (server). State is preserved in `/persist` via `environment.persistence` bind-mounts.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.impermanence.enable` | `bool` | `false` | Enable impermanence. |
| `nerv.impermanence.mode` | `"btrfs" \| "full"` | required | Persistence strategy. |
| `nerv.impermanence.persistPath` | `str` | `"/persist"` | Base path for `environment.persistence` (full mode only). |
| `nerv.impermanence.extraDirs` | `[str]` | `[]` | Additional system paths to mount as tmpfs. |
| `nerv.impermanence.users` | `attrs` | `{}` | Per-user paths mapped to tmpfs size. |

---

## Mode: `btrfs`

Used with `nerv.disko.layout = "btrfs"`.

**How it works:** An initrd systemd service runs before `/` is mounted. It snapshots `@root-blank → @`, effectively resetting `/` to a clean baseline on every boot. This happens entirely in the initrd before userspace starts.

**What persists** (via `environment.persistence` bind-mounts from `/persist`):

| Path | Reason |
|------|--------|
| `/var/lib/nixos` | NixOS user/group IDs |
| `/var/lib/systemd` | systemd unit state (timers, etc.) |
| `/etc/nixos` | NERV flake config |
| `/etc/ssh/ssh_host_ed25519_key` + `.pub` | SSH host key |
| `/etc/ssh/ssh_host_rsa_key` + `.pub` | SSH host key |
| `/etc/machine-id` | Stable machine identity |

**Note:** `/var/log` is NOT in `environment.persistence` for BTRFS mode — it uses the `@log` BTRFS subvolume directly, which avoids a double-mount conflict.

---

## Mode: `full`

Used with `nerv.disko.layout = "lvm"`.

**How it works:** `/` is mounted as a `tmpfs` (2 GB, mode 755). Everything on `/` is ephemeral and disappears on reboot.

**What persists** (via `environment.persistence` bind-mounts from `/persist`):

| Path | Reason |
|------|--------|
| `/var/log` | System logs |
| `/var/lib/nixos` | NixOS user/group IDs |
| `/var/lib/systemd` | systemd unit state |
| `/etc/nixos` | NERV flake config |
| `/etc/ssh/ssh_host_ed25519_key` + `.pub` | SSH host key |
| `/etc/ssh/ssh_host_rsa_key` + `.pub` | SSH host key |
| `/etc/machine-id` | Stable machine identity |

> **tmpfs size note:** Root tmpfs is hardcoded at 2 GB. For servers with large ephemeral working sets, override with `lib.mkForce`:
> ```nix
> fileSystems."/".options = lib.mkForce [ "size=8G" "mode=755" ];
> ```

---

## Adding extra persistent directories

### System-wide

```nix
nerv.impermanence.extraDirs = [
  "/var/cache/myapp"
  "/var/lib/docker"
];
```

### Per-user tmpfs mounts

```nix
# key = path, value = tmpfs size
nerv.impermanence.users.alice = {
  "/home/alice/Downloads" = "8G";
  "/home/alice/Projects"  = "20G";
};
```

---

## Adding custom persistence with environment.persistence

You can extend `environment.persistence` directly in `hosts/configuration.nix`:

```nix
environment.persistence."/persist" = {
  directories = [
    "/var/lib/docker"
    "/var/lib/postgresql"
  ];
  files = [
    "/etc/hostname"
  ];
};
```

---

## Secure Boot interaction

When `nerv.secureboot.enable = true`, Secure Boot keys at `/var/lib/sbctl` must be persisted. NERV emits a `lib.warn` if `sbctl` is not covered by `environment.persistence`. Add it explicitly:

```nix
environment.persistence."/persist".directories = [
  "/var/lib/sbctl"
];
```

---

## Example: desktop configuration

```nix
nerv.impermanence.enable = true;
nerv.impermanence.mode   = "btrfs";

nerv.impermanence.users.alice = {
  "/home/alice/Downloads" = "8G";
};
```

## Example: server configuration

```nix
nerv.impermanence.enable      = true;
nerv.impermanence.mode        = "full";
nerv.impermanence.persistPath = "/persist";

nerv.impermanence.extraDirs = [
  "/var/lib/postgresql"
];
```
