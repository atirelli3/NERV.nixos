# Service: ZSH

**File:** `modules/services/zsh.nix`

ZSH as the system shell with plugins and shell aliases. Enabled by default.

---

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `nerv.zsh.enable` | `bool` | `true` | Enable ZSH as system shell with plugins. |

---

## What it enables

| Feature | Details |
|---------|---------|
| ZSH system shell | `programs.zsh.enable = true` |
| Autosuggestions | `zsh-autosuggestions` — grays out command suggestions from history |
| Syntax highlighting | `zsh-syntax-highlighting` — colors commands while typing |
| History substring search | `zsh-history-substring-search` — search history with arrow keys |
| fzf integration | `fzf` — fuzzy file/command search (`Ctrl+R`, `Ctrl+T`, `Alt+C`) |

**Plugin load order (fixed):** autosuggestions → syntax-highlighting → history-substring-search

The order matters — plugins are sourced manually in this sequence to ensure correct keybinding initialization.

---

## Installed packages

| Package | Use |
|---------|-----|
| `eza` | Modern `ls` replacement |
| `fzf` | Fuzzy finder with shell integration |
| `zsh-syntax-highlighting` | Syntax coloring for ZSH |
| `zsh-history-substring-search` | Arrow-key history search |

---

## Shell aliases

| Alias | Expands to | Description |
|-------|-----------|-------------|
| `ls` | `eza --icons` | List with icons |
| `ll` | `eza --icons -la` | Long list with icons |
| `la` | `eza --icons -a` | All files with icons |
| `lt` | `eza --icons --tree` | Tree view with icons |
| `nrs` | `sudo nixos-rebuild switch --flake /etc/nixos#host` | Rebuild and switch |
| `nrb` | `sudo nixos-rebuild boot --flake /etc/nixos#host` | Rebuild for next boot |
| `nrt` | `sudo nixos-rebuild test --flake /etc/nixos#host` | Test without switching |

> **Note:** `nrs`, `nrb`, `nrt` are hardcoded to `#host`. Override for server use:
> ```nix
> programs.zsh.shellAliases.nrs = lib.mkForce
>   "sudo nixos-rebuild switch --flake /etc/nixos#server";
> ```

---

## Example

```nix
# ZSH is enabled by default — no configuration needed.

# To disable:
nerv.zsh.enable = false;
```

---

## Usage tips

```bash
# Ctrl+R — fuzzy search command history
# Ctrl+T — fuzzy file search in current directory
# Alt+C  — fuzzy cd into subdirectory

# History substring search
# Type part of a command, then use Up/Down arrows to search

# Autosuggestions
# Type a command, see grayed suggestion from history, press → to accept
```

---

## Notes

- `nerv.zsh.enable` interacts with `nerv.primaryUser`: if both are active, primary users get ZSH set as their login shell automatically (wired in `modules/system/identity.nix`)
- Personal ZSH configuration (themes, additional plugins, custom functions) belongs in `~/home.nix` via Home Manager's `programs.zsh` options
