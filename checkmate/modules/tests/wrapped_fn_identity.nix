# Reynolds: extractClassSingle creates a new function wrapper for __isWrappedFn
# attrsets. Test that the same parametric provider referenced at two positions
# produces correct results without module system conflicts.
{
  mkFlake,
  evalMod,
  lib,
  ...
}:
{

  # A parametric provider included from two different aspects should
  # produce correct resolved content at both positions.
  flake.tests."test wrapped fn at two include sites" =
    let
      flake = mkFlake {
        flake.aspects =
          { aspects, ... }:
          {
            aspectOne = {
              includes = [ (aspects.aspectThree.provides.greeter { who = "from-one"; }) ];
              classOne.bar = [ "one" ];
            };

            aspectTwo = {
              includes = [ (aspects.aspectThree.provides.greeter { who = "from-two"; }) ];
              classOne.bar = [ "two" ];
            };

            aspectThree.provides.greeter =
              { who }:
              {
                classOne.bar = [ "hello ${who}" ];
              };
          };
      };
      one = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectOne).bar;
      two = lib.sort (a: b: a < b) (evalMod "classOne" flake.modules.classOne.aspectTwo).bar;
    in
    {
      expr = { inherit one two; };
      expected = {
        one = [
          "hello from-one"
          "one"
        ];
        two = [
          "hello from-two"
          "two"
        ];
      };
    };

}
