{
  inputs ? { },
  lib,
}:
let
  # No-flakes import: resolve gen from flake.lock
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  lockedGen = lock.nodes.gen.locked;
  genSrc = builtins.fetchTarball {
    url = "https://github.com/${lockedGen.owner}/${lockedGen.repo}/archive/${lockedGen.rev}.zip";
    sha256 = lockedGen.narHash;
  };
  gen = inputs.gen or (import genSrc { });

  types = import ./types.nix { inherit lib gen; };
  resolve = import ./resolve.nix { inherit lib gen; };
  identity = import ./identity.nix lib;
  transpose =
    {
      emit ? lib.singleton,
    }:
    import ./default.nix { inherit lib emit; };
  aspects = import ./aspects.nix lib;
  forward = import ./forward.nix { inherit lib gen; };
  new = import ./new.nix { inherit lib gen; };
  new-scope = import ./new-scope.nix new;
in
{
  inherit
    types
    transpose
    aspects
    new
    new-scope
    forward
    resolve
    identity
    ;
  inherit (gen) search mkIntensional intensionalEq;
}
