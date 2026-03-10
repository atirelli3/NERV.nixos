# modules/default.nix
#
# Top-level aggregator — imports system, services, and home module subtrees.
{ imports = [ ./system ./services ../home ]; }
