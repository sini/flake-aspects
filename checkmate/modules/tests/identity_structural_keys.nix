{ identity, lib, ... }:
{
  flake.tests."test structural keys contains expected keys" = {
    expr = lib.sort (a: b: a < b) (builtins.attrNames identity.structuralKeysSet);
    expected = lib.sort (a: b: a < b) [
      "name"
      "description"
      "meta"
      "includes"
      "provides"
      "__functor"
      "__functionArgs"
      "__isWrappedFn"
      "modules"
      "resolve"
      "key"
      "imports"
      "_module"
      "_"
    ];
  };

  flake.tests."test content keys not in structural set" = {
    expr = {
      nixos = identity.structuralKeysSet ? nixos;
      classOne = identity.structuralKeysSet ? classOne;
      docker = identity.structuralKeysSet ? docker;
    };
    expected = {
      nixos = false;
      classOne = false;
      docker = false;
    };
  };
}
