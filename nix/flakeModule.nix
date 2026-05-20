# Flake-parts integration for aspect-oriented configuration
# Provides flake.aspects (input) and flake.modules (output)

{
  lib,
  config,
  ...
}:
let
  # Resolve gen from flake.lock (no-flakes pattern)
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  lockedGen = lock.nodes.gen.locked;
  genSrc = builtins.fetchTarball {
    url = "https://github.com/${lockedGen.owner}/${lockedGen.repo}/archive/${lockedGen.rev}.zip";
    sha256 = lockedGen.narHash;
  };
  gen = import genSrc { };
in
# Invoke new() factory to create flake.aspects and flake.modules
import ./new.nix { inherit lib gen; } (option: transposed: {
  # User-facing aspects input
  options.flake.aspects = option;

  # Computed modules output organized by class
  config.flake.modules = transposed;
}) config.flake.aspects
