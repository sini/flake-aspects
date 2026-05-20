{ mkFlake, identity, ... }:
{
  flake.tests."test provides aspect has correct identity" =
    let
      flake = mkFlake {
        flake.aspects.infra.provides.networking.classOne.bar = [ "net" ];
      };
      aspect = flake.aspects.infra.provides.networking;
    in
    {
      expr = {
        chain = aspect.meta.aspect-chain;
        name = aspect.name;
      };
      expected = {
        chain = [ "infra" ];
        name = "networking";
      };
    };

  flake.tests."test nested aspect has correct aspect-chain" =
    let
      flake = mkFlake {
        flake.aspects.infra.provides.networking.provides.dns.classOne.bar = [ "dns" ];
      };
      aspect = flake.aspects.infra.provides.networking.provides.dns;
    in
    {
      expr = {
        chain = aspect.meta.aspect-chain;
        name = aspect.name;
        key = identity.key aspect;
      };
      expected = {
        chain = [
          "infra"
          "networking"
        ];
        name = "dns";
        key = "infra/networking/dns";
      };
    };
}
