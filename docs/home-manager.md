# Home Manager Integration

NERV wires Home Manager as a NixOS module so each user manages their own dotfiles in `~/home.nix`. The system repo does not contain user dotfiles.

---

## How it works

`home/default.nix` generates a `home-manager.users` attrset from the `nerv.home.users` list. Each listed user imports `/home/<name>/home.nix` at build time. This file is outside the flake boundary — hence `--impure` is required.

---

## Enabling Home Manager

```nix
# hosts/configuration.nix  (or in the flake.nix profile attrset)
nerv.home.enable = true;
nerv.home.users  = [ "alice" "bob" ];
```

Each listed user must create `~/home.nix` on the target machine before the first `nixos-rebuild`.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.home.enable` | `bool` | `false` | Enable Home Manager NixOS integration. |
| `nerv.home.users` | `[str]` | `[]` | Usernames to wire. Each must have `~/home.nix`. |

---

## Creating `~/home.nix`

On the target machine, each user creates their own config:

```nix
# /home/alice/home.nix
{ pkgs, ... }: {
  home.username    = "alice";
  home.homeDirectory = "/home/alice";

  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    git
    neovim
    ripgrep
  ];

  programs.git = {
    enable    = true;
    userName  = "Alice";
    userEmail = "alice@example.com";
  };
}
```

---

## Rebuilding

Because `~/home.nix` is outside the flake boundary, `--impure` is required:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#host --impure
```

---

## Impermanence and Home Manager

When using impermanence, Home Manager configuration files written to `~/.config`, `~/.local`, etc. are ephemeral unless you persist them explicitly.

**Option 1 — Persist user home directories:**
```nix
# hosts/configuration.nix
nerv.impermanence.users.alice = {
  "/home/alice/Downloads" = "8G";
};
```

**Option 2 — Use Home Manager's own persistence:**
```nix
# /home/alice/home.nix
home.persistence."/persist/home/alice" = {
  directories = [
    ".config/nvim"
    ".ssh"
    "Projects"
  ];
};
```

> Note: Option 2 requires `impermanence` in your Home Manager inputs.

---

## Caveats

- If a user listed in `nerv.home.users` does not have `~/home.nix`, `nixos-rebuild` fails with an import error
- Removing a user from `nerv.home.users` does not affect their `~/home.nix` — the file can be left in place
- `home-manager.backupFileExtension = "backup"` is set to prevent hard failures on conflicting unmanaged files
