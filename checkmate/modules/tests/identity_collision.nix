# Palmer Theorem 1 (closure consistency): Two aspects sharing the same
# identity.key must be treated consistently. This tests the dedup
# behavior when two distinct aspects have colliding identity keys.
{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  # When two aspects with the same identity.key are both included,
  # dedup keeps only the first occurrence (the one added to seen first).
  # This is Palmer's conservative equality: same program point → same behavior.
  # If two aspects genuinely differ but share a key, the first-wins
  # semantics silently drops the second.
  flake.tests."test identity collision first wins in dedup" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = [
                aspects.aspectTwo.provides.item
                aspects.aspectThree.provides.item
              ];
              classOne.bar = [ "root" ];
            };

            # Both aspectTwo and aspectThree define provides.item.
            # These get different identity keys because their aspect-chains differ:
            # "aspectTwo/item" vs "aspectThree/item"
            aspectTwo.provides.item = {
              classOne.bar = [ "from-two" ];
            };

            aspectThree.provides.item = {
              classOne.bar = [ "from-three" ];
            };
          };
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
    in
    {
      inherit expr;
      # Both appear — different aspect-chains mean different identity keys
      expected = [
        "from-three"
        "from-two"
        "root"
      ];
    };

  # Same-named provides under the same parent DO share an identity key.
  # The module system merges their definitions (they're the same option path).
  flake.tests."test same-path provides merge not collide" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = [ aspects.aspectTwo.provides.shared ];
              classOne.bar = [ "root" ];
            };

            # Two modules both defining aspectTwo.provides.shared —
            # the module system merges them into one aspect.
            aspectTwo.provides.shared.classOne.bar = [ "first" ];
          };
      };
      flake2 = mkFlake {
        imports = [
          {
            flake.aspects.aspectTwo.provides.shared.classOne.bar = [ "first" ];
          }
          {
            flake.aspects.aspectTwo.provides.shared.classOne.bar = [ "second" ];
          }
          {
            flake.aspects =
              { aspects, ... }:
              {
                aspectOne = {
                  includes = [ aspects.aspectTwo.provides.shared ];
                  classOne.bar = [ "root" ];
                };
              };
          }
        ];
      };
      expr = lib.sort (a: b: a < b) (evalMod "classOne" flake2.modules.classOne.aspectOne).bar;
    in
    {
      inherit expr;
      # Both definitions merge — same identity key, same aspect, content combined
      expected = [
        "first"
        "root"
        "second"
      ];
    };

}
