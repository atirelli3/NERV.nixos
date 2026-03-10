# modules/services/default.nix
#
# Aggregates all nerv service modules. zsh enabled by default; all others disabled unless explicitly enabled.
{ imports = [
    ./openssh.nix
    ./pipewire.nix
    ./bluetooth.nix
    ./printing.nix
    ./zsh.nix
  ];
}
