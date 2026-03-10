# Service: OpenSSH

**File:** `modules/services/openssh.nix`

SSH daemon with endlessh tarpit and fail2ban brute-force protection. Disabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.openssh.enable` | `bool` | `false` | Enable SSH daemon. |
| `nerv.openssh.port` | `port` | `2222` | SSH listener port. Connect with `ssh -p 2222 user@host`. |
| `nerv.openssh.tarpitPort` | `port` | `22` | endlessh tarpit port. Must differ from `port`. |
| `nerv.openssh.allowUsers` | `[str]` | `[]` | Restrict SSH to listed users. Empty = all authenticated users allowed. |
| `nerv.openssh.passwordAuth` | `bool` | `false` | Allow password authentication. Key-only by default. |
| `nerv.openssh.kbdInteractiveAuth` | `bool` | `false` | Allow keyboard-interactive authentication. |

---

## Components

### SSH daemon

Hardened defaults:

- `PermitRootLogin = "no"` — root login always disabled
- `PasswordAuthentication = false` — key-based only by default
- `KbdInteractiveAuthentication = false`
- SSH host keys persisted via `environment.persistence` (see [Impermanence](../modules/impermanence.md))

### endlessh tarpit

[endlessh](https://github.com/skeeto/endlessh) listens on `nerv.openssh.tarpitPort` (default: 22) and sends an infinitely slow SSH banner to connecting bots, wasting their time and connection slots.

Real SSH connections go to `nerv.openssh.port` (default: 2222).

### fail2ban

Brute-force protection via fail2ban:

| Parameter | Value |
|-----------|-------|
| Global max retries | 5 |
| SSH retries before ban | 3 (within 10 minutes) |
| Initial ban duration | 24 hours |
| Ban growth | Exponential, capped at 168 hours (7 days) |
| LAN whitelist | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |

```bash
# View banned IPs
sudo fail2ban-client status sshd

# Unban an IP
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

---

## Example configurations

### Minimal — key-only, no restrictions

```nix
nerv.openssh.enable = true;
```

### Restrict to specific users

```nix
nerv.openssh.enable     = true;
nerv.openssh.allowUsers = [ "alice" "ops" ];
```

### Custom ports

```nix
nerv.openssh.enable      = true;
nerv.openssh.port        = 4222;
nerv.openssh.tarpitPort  = 22;
```

### Enable password auth (not recommended)

```nix
nerv.openssh.enable       = true;
nerv.openssh.passwordAuth = true;
```

---

## Connecting

```bash
# Default port
ssh -p 2222 alice@my-server

# Add to ~/.ssh/config for convenience
Host my-server
  HostName 192.168.1.100
  Port 2222
  User alice
  IdentityFile ~/.ssh/id_ed25519
```

---

## Assertions

- `nerv.openssh.tarpitPort` must differ from `nerv.openssh.port` — prevents the SSH daemon and tarpit from colliding on the same port.
