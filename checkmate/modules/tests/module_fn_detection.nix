{ isModuleFn, ... }:
let
  # Test lambdas for isModuleFn detection
  # These intentionally have specific argument patterns
  configFn =
    { config, ... }:
    {
      inherit config;
    };
  libFn =
    { lib, ... }:
    {
      inherit lib;
    };
  pkgsFn =
    { pkgs, ... }:
    {
      inherit pkgs;
    };
  optionsFn =
    { options, ... }:
    {
      inherit options;
    };
  singleArgFn =
    { message }:
    {
      inherit message;
    };
  multiArgFn =
    { host, user }:
    {
      inherit host user;
    };
in
{
  flake.tests."test isModuleFn detects config arg" = {
    expr = isModuleFn configFn;
    expected = true;
  };

  flake.tests."test isModuleFn detects lib arg" = {
    expr = isModuleFn libFn;
    expected = true;
  };

  flake.tests."test isModuleFn detects pkgs arg" = {
    expr = isModuleFn pkgsFn;
    expected = true;
  };

  flake.tests."test isModuleFn detects options arg" = {
    expr = isModuleFn optionsFn;
    expected = true;
  };

  flake.tests."test isModuleFn rejects parametric single arg" = {
    expr = isModuleFn singleArgFn;
    expected = false;
  };

  flake.tests."test isModuleFn rejects parametric multi arg" = {
    expr = isModuleFn multiArgFn;
    expected = false;
  };

  flake.tests."test isModuleFn rejects attrset" = {
    expr = isModuleFn { foo = 1; };
    expected = false;
  };
}
