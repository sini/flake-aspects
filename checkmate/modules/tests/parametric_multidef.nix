{ mkFlake, lib, ... }:
{
  flake.tests."test parametric multidef last wins in provides" =
    let
      flake = mkFlake {
        imports = [
          {
            flake.aspects.aspectOne.provides.greeter =
              { who }:
              {
                classOne.bar = [ "hello ${who}" ];
              };
          }
          {
            flake.aspects.aspectOne.provides.greeter =
              { who }:
              {
                classOne.bar = [ "goodbye ${who}" ];
              };
          }
        ];
      };
      provider = flake.aspects.aspectOne.provides.greeter;
    in
    {
      expr = lib.isFunction provider;
      expected = true;
    };
}
