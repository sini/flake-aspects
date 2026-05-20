# Palmer §3 (Search monad dedup): Diamond includes and dedup behavior.
{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  # Same-chain dedup: when an aspect is included, then included again
  # deeper in the same chain, the seen set catches it.
  flake.tests."test include dedup same chain" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = with aspects; [
                aspectTwo
                aspectThree
              ];
              classOne.bar = [ "one" ];
            };

            # aspectTwo includes aspectThree — which aspectOne also includes directly
            aspectTwo = {
              includes = [ aspects.aspectThree ];
              classOne.bar = [ "two" ];
            };

            aspectThree = {
              classOne.bar = [ "three" ];
            };
          };
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
    in
    {
      inherit expr;
      expected = [
        "one"
        "three"
        "two"
      ];
    };

  # Cross-sibling diamond (Palmer §3): aspectTwo and aspectThree both include
  # the same provides.shared. The fold-based collect threads seen across
  # sibling includes, deduplicating the diamond.
  flake.tests."test diamond cross-sibling dedup" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = with aspects; [
                aspectTwo
                aspectThree
              ];
              classOne.bar = [ "top" ];
            };

            aspectTwo = {
              includes = [ aspects.aspectTwo.provides.shared ];
              classOne.bar = [ "left" ];
              provides.shared = {
                classOne.bar = [ "shared" ];
              };
            };

            aspectThree = {
              includes = [ aspects.aspectTwo.provides.shared ];
              classOne.bar = [ "right" ];
            };
          };
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
    in
    {
      inherit expr;
      # "shared" appears once — fold-based collect (Palmer §3) deduplicates across siblings
      expected = [
        "left"
        "right"
        "shared"
        "top"
      ];
    };

}
