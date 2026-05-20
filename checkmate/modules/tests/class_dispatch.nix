# Test that registered classes produce clean deferred module content
# (no structural keys) while unregistered keys get full aspect treatment.
{
  lib,
  types,
  resolve,
  ...
}:
let
  # Create aspects with registered class names
  mkEval =
    mod:
    lib.evalModules {
      modules = [
        {
          options.aspects = lib.mkOption {
            type = types.aspectsType { classes.myclass = true; };
            default = { };
          };
        }
        mod
      ];
    };
in
{
  flake.tests."test registered class content is deferred module" =
    let
      eval = mkEval { config.aspects.myAspect.myclass.setting = "hello"; };
      classVal = eval.config.aspects.myAspect.myclass;
    in
    {
      # deferredModule.merge produces { imports = [...]; } — no structural keys
      expr = {
        hasImports = classVal ? imports;
        onlyImports = builtins.attrNames classVal == [ "imports" ];
        noName = !(classVal ? name);
        noIncludes = !(classVal ? includes);
      };
      expected = {
        hasImports = true;
        onlyImports = true;
        noName = true;
        noIncludes = true;
      };
    };

  flake.tests."test registered class has no structural keys" =
    let
      eval = mkEval { config.aspects.myAspect.myclass.setting = "hello"; };
      classEval = lib.evalModules {
        modules = [
          { options.setting = lib.mkOption { type = lib.types.str; }; }
          eval.config.aspects.myAspect.myclass
        ];
      };
    in
    {
      expr = classEval.config.setting;
      expected = "hello";
    };

  flake.tests."test unregistered key is still an aspect" =
    let
      eval = mkEval {
        config.aspects.myAspect.nestedAspect.myclass.foo = "bar";
      };
      nested = eval.config.aspects.myAspect.nestedAspect;
    in
    {
      expr = {
        hasName = nested ? name;
        hasIncludes = nested ? includes;
        name = nested.name;
      };
      expected = {
        hasName = true;
        hasIncludes = true;
        name = "nestedAspect";
      };
    };

  flake.tests."test resolve with registered classes skips extractClass" =
    let
      eval = mkEval (
        { config, ... }:
        {
          config.aspects.myAspect = {
            includes = [ config.aspects.helper ];
            myclass.bar = [ "from-main" ];
          };
          config.aspects.helper.myclass.bar = [ "from-helper" ];
        }
      );
      resolved = resolve "myclass" [ ] eval.config.aspects.myAspect;
      result = lib.evalModules {
        modules = [
          {
            options.bar = lib.mkOption { type = lib.types.listOf lib.types.str; };
          }
        ] ++ resolved.imports;
      };
    in
    {
      expr = lib.sort (a: b: a < b) result.config.bar;
      expected = [ "from-helper" "from-main" ];
    };
}
