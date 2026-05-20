lib:
let
  types = import ./types.nix lib;
  resolve = import ./resolve.nix lib;
  identity = import ./identity.nix lib;
  transpose =
    {
      emit ? lib.singleton,
    }:
    import ./default.nix { inherit lib emit; };
  aspects = import ./aspects.nix lib;
  forward = import ./forward.nix lib;
  new = import ./new.nix lib;
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
  inherit (types) mkIntensional;
}
