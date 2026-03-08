# modules/services/zsh.nix
#
# Purpose  : Zsh system shell with history management, key bindings, aliases, and fzf integration.
# Options  : nerv.zsh.enable (default: false)
# Defaults : disabled; histSize = 10000; syntaxHighlighting sourced manually to enforce load order.
# Override : lib.mkForce on any programs.zsh.* setting.
# Note     : syntaxHighlighting.enable is set false in the NixOS wrapper and sourced manually in
#            interactiveShellInit to enforce load order:
#            autosuggestions -> syntax-highlighting -> history-substring-search.
#            NixOS aliases target /etc/nixos#host.

{ config, lib, pkgs, ... }:

let
  cfg = config.nerv.zsh;
in {
  options.nerv.zsh.enable = lib.mkEnableOption "Zsh system shell with keybindings, aliases, and fzf integration";

  config = lib.mkIf cfg.enable {
    users.defaultUserShell    = pkgs.zsh;
    users.users.root.shell    = pkgs.zsh; # defaultUserShell does not apply to root

    programs.zsh = {
      enable = true;

      # autosuggestions is safe to enable via the NixOS wrapper.
      # syntaxHighlighting is intentionally disabled here — it is sourced manually
      # in interactiveShellInit to enforce the required load order:
      #   autosuggestions → syntax-highlighting → history-substring-search
      autosuggestions.enable = true;
      syntaxHighlighting.enable = false;

      histSize = 10000;

      setOptions = [
        "HIST_IGNORE_ALL_DUPS"   # no duplicate entries in history
        "HIST_SAVE_NO_DUPS"      # don't write duplicates to histfile
        "SHARE_HISTORY"          # share history across sessions
        "AUTO_CD"                # type a dir name to cd into it
        "INTERACTIVE_COMMENTS"   # allow # comments in interactive shell
        "COMPLETE_IN_WORD"       # complete from both ends of a word
        "ALWAYS_TO_END"          # move cursor to end after completion
      ];

      # plugins = [
      #   {
      #     # Up/down arrows search history by current prefix
      #     name = "zsh-history-substring-search";
      #     src  = "${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search";
      #   }
      # ];

      shellAliases = {
        # Navigation
        ls    = "eza";
        ll    = "eza -lh --git";
        la    = "eza -lah --git";
        lt    = "eza --tree";
        ".."  = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        mkdir  = "mkdir -p";
        cp     = "cp -i";
        mv     = "mv -i";

        # Git
        g    = "git";
        gs   = "git status";
        ga   = "git add";
        gaa  = "git add --all";
        gc   = "git commit";
        gcm  = "git commit -m";
        gca  = "git commit --amend --no-edit";
        gp   = "git push";
        gpl  = "git pull";
        gl   = "git log --oneline --graph --decorate";
        gd   = "git diff";
        gds  = "git diff --staged";
        gco  = "git checkout";
        gb   = "git branch";
        gst  = "git stash";
        gsp  = "git stash pop";

        # Nix / NixOS
        nrs  = "sudo nixos-rebuild switch --flake /etc/nixos#host";
        nrb  = "sudo nixos-rebuild boot   --flake /etc/nixos#host";
        nrt  = "sudo nixos-rebuild test   --flake /etc/nixos#host";
        nfu  = "sudo nix flake update /etc/nixos";
        ngc  = "sudo nix-collect-garbage -d";
        nso  = "sudo nix store optimise";
        nsh  = "nix shell nixpkgs#";
        ndev = "nix develop";
      };

      interactiveShellInit = ''
        # Load order: syntax-highlighting must precede history-substring-search,
        # otherwise history-substring-search's ZLE widget wrapping breaks.
        # autosuggestions is already sourced earlier by its NixOS wrapper.
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh

        # History substring search — bind to arrow keys
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down

        # Word navigation — Ctrl+Left / Ctrl+Right
        bindkey '^[[1;5C' forward-word
        bindkey '^[[1;5D' backward-word

        # Home / End / Delete
        bindkey '^[[H'  beginning-of-line
        bindkey '^[[F'  end-of-line
        bindkey '^[[3~' delete-char

        # fzf — fuzzy completion (**<TAB>) and key bindings:
        #   Ctrl+T  fuzzy-find file and paste to command line
        #   Ctrl+R  fuzzy search command history
        #   Alt+C   fuzzy cd into subdirectory
        export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border=none'
        source ${pkgs.fzf}/share/fzf/completion.zsh
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh

        # sudo widget — ESC ESC prepends/removes sudo on the current line
        sudo-command-line() {
          [[ -z $BUFFER ]] && zle up-history
          if [[ $BUFFER == sudo\ * ]]; then
            LBUFFER="''${LBUFFER#sudo }"
          else
            LBUFFER="sudo $LBUFFER"
          fi
        }
        zle -N sudo-command-line
        bindkey '^[^[' sudo-command-line
      '';
    };

    environment.systemPackages = with pkgs; [ eza fzf ];
  };
}
