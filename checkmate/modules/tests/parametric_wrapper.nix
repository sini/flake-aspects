{ mkFlake, lib, ... }:
{
  flake.tests."test parametric single-def produces wrapper" =
    let
      flake = mkFlake {
        flake.aspects.myAspect.provides.greeter =
          { who }:
          {
            classOne.bar = [ "hello ${who}" ];
          };
      };
      provider = flake.aspects.myAspect.provides.greeter;
    in
    {
      expr = {
        isCallable = lib.isFunction provider;
        hasFunctionArgs = provider ? __functionArgs;
        fnArgsMatch = lib.functionArgs provider;
      };
      expected = {
        isCallable = true;
        hasFunctionArgs = true;
        fnArgsMatch = {
          who = false;
        };
      };
    };

  flake.tests."test parametric wrapper is callable" =
    let
      flake = mkFlake {
        flake.aspects.myAspect.provides.greeter =
          { who }:
          {
            classOne.bar = [ "hello ${who}" ];
          };
      };
      provider = flake.aspects.myAspect.provides.greeter;
      result = provider { who = "world"; };
    in
    {
      # functionTo(aspectSubmodule) wrapping means the result is a full aspect
      expr = {
        isAspect = result ? resolve;
        hasClassOne = result ? classOne;
      };
      expected = {
        isAspect = true;
        hasClassOne = true;
      };
    };
}
