# Module: Identity

**File:** `modules/system/identity.nix`

Sets hostname, locale, timezone, keymap, and primary user group membership. Always active.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.hostname` | `str` | required | Sets `networking.hostName`. Must not be empty. |
| `nerv.primaryUser` | `[str]` | `[]` | Users to add to `wheel` + `networkmanager` groups. Sets ZSH as shell if `nerv.zsh.enable = true`. |
| `nerv.locale.timeZone` | `str` | `"UTC"` | Sets `time.timeZone`. See `timedatectl list-timezones`. |
| `nerv.locale.defaultLocale` | `str` | `"en_US.UTF-8"` | Sets `i18n.defaultLocale`. |
| `nerv.locale.keyMap` | `str` | `"us"` | Sets `console.keyMap`. |

---

## What it does

- Sets `networking.hostName` to `nerv.hostname`
- Applies locale and timezone settings
- For each user in `nerv.primaryUser`, appends them to `users.users.<name>.extraGroups` with `wheel` and `networkmanager`
- If `nerv.zsh.enable = true`, sets the user's shell to `pkgs.zsh`

---

## Example

```nix
nerv.hostname    = "nerv-desktop";
nerv.primaryUser = [ "alice" ];

nerv.locale.timeZone      = "Europe/Rome";
nerv.locale.defaultLocale = "en_US.UTF-8";
nerv.locale.keyMap        = "it";
```

---

## Assertions

- `nerv.hostname` must not be the empty string — prevents building a nameless machine.

---

## Cross-module interactions

- `nerv.primaryUser` interacts with `nerv.zsh.enable` from `modules/services/zsh.nix`: if ZSH is enabled, each primary user gets ZSH as their login shell
- Group wiring (`wheel`, `networkmanager`) is consumed by `modules/system/security.nix` (sudo restricted to wheel) and `modules/system/nix.nix` (Nix daemon access restricted to `@wheel`)
