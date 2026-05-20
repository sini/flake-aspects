lib:
let
  resolve = import ./resolve.nix lib;

  isModuleFn =
    fn:
    builtins.isFunction fn
    && (
      let
        args = builtins.functionArgs fn;
      in
      args ? config || args ? options || args ? lib || args ? pkgs
    );

  ignoredType = lib.types.mkOptionType {
    name = "ignored type";
    description = "ignored values";
    merge = _loc: _defs: null;
    check = _: true;
  };

  mkInternal =
    desc: type: fn:
    lib.mkOption {
      internal = true;
      visible = false;
      readOnly = true;
      description = desc;
      inherit type;
      apply = fn;
    };

  functorType = lib.types.mkOptionType {
    name = "aspectFunctor";
    description = "aspect functor function";
    check = lib.isFunction;
    merge =
      _loc: defs:
      let
        lastDef = lib.last defs;
      in
      {
        __functionArgs = lib.functionArgs lastDef.value;
        __functor =
          _: callerArgs:
          let
            result = lastDef.value callerArgs;
          in
          if builtins.isFunction result then result else _: result;
      };
  };

  # Palmer's flat aspect type. ONE type, ONE merge, no recursive type references.
  # Accepts functions and attrsets. Functions are wrapped as callable attrsets
  # (defunctionalized). Attrsets merge through aspectSubmodule. No either chains.
  aspectType =
    cnf:
    lib.types.mkOptionType {
      name = "aspect";
      description = "aspect or function";
      check = v: builtins.isAttrs v || builtins.isFunction v;
      merge =
        loc: defs:
        let
          # Palmer's defunctionalization with functionTo semantics:
          # - Tagged (__isWrappedFn) for passthrough recognition
          # - functionArgs preserved for inspection
          # - __functor types return value through aspectSubmodule (curried chain support)
          wrapFn =
            fn:
            let
              ft = (lib.types.functionTo (aspectSubmodule cnf)).merge (loc ++ [ "<function body>" ]) [
                {
                  file = "<wrapped>";
                  value = fn;
                }
              ];
            in
            ft // { __isWrappedFn = true; };

          isWrapped = d: builtins.isAttrs d.value && (d.value.__isWrappedFn or false);

          # Partition defs
          fnDefs = builtins.filter (d: builtins.isFunction d.value) defs;
          wrappedDefs = builtins.filter isWrapped defs;
          attrDefs = builtins.filter (d: builtins.isAttrs d.value && !(d.value.__isWrappedFn or false)) defs;
        in
        if wrappedDefs != [ ] && fnDefs == [ ] && attrDefs == [ ] then
          # All wrapped fns — pass through the last one
          (lib.last wrappedDefs).value
        else if fnDefs == [ ] && wrappedDefs == [ ] then
          # All attrsets — merge through aspectSubmodule
          (aspectSubmodule cnf).merge loc defs
        else if attrDefs == [ ] && wrappedDefs == [ ] && builtins.length fnDefs == 1 then
          let
            fn = (builtins.head fnDefs).value;
            args = builtins.functionArgs fn;
            isSubmoduleFn = args ? lib || args ? config || args ? options || args ? aspect;
          in
          if isSubmoduleFn then
            # Submodule function (uses _module.args) — let aspectSubmodule evaluate it as a module
            (aspectSubmodule cnf).merge loc fnDefs
          else
            # Pure parametric function — wrap as callable attrset
            wrapFn fn
        else
          # Multiple functions, or mixed fns + attrsets —
          # coerce functions to { includes = [fn]; }, merge through aspectSubmodule
          (aspectSubmodule cnf).merge loc (
            map (
              d:
              if builtins.isFunction d.value then
                d
                // {
                  value = {
                    includes = [ d.value ];
                  };
                }
              else
                d
            ) defs
          );
    };

  # Non-recursive aspect submodule. Uses aspectType only via `either`
  # in provides (safe: either doesn't force merge during construction)
  # and providerType for includes (safe: mutual lazy recursion in let block).
  aspectSubmodule =
    cnf:
    lib.types.submodule (
      { name, config, ... }:
      {
        freeformType = lib.types.lazyAttrsOf lib.types.deferredModule;
        config._module.args.aspect = config;
        imports = [ (lib.mkAliasOptionModule [ "_" ] [ "provides" ]) ];

        options = {
          name = lib.mkOption {
            description = "Aspect name";
            default = name;
            type = lib.types.str;
          };

          description = lib.mkOption {
            description = "Aspect description";
            default = "Aspect ${name}";
            type = lib.types.str;
          };

          meta = lib.mkOption {
            description = "Aspect metadata";
            default = { };
            type = lib.types.submodule {
              freeformType = lib.types.lazyAttrsOf lib.types.raw;
              options.aspect-chain = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = cnf.aspectChain or [ ];
                description = "Chain of ancestor aspect names from root to parent";
              };
            };
          };

          # either: try aspectType first (wraps fns as callable attrsets),
          # fall back to aspectSubmodule (coerces fns to includes).
          # This is safe because either doesn't force subtypes during construction.
          includes = lib.mkOption {
            description = "Aspects to include";
            type = lib.types.listOf (lib.types.either (aspectType cnf) (aspectSubmodule cnf));
            default = [ ];
          };

          provides = lib.mkOption {
            description = "Named sub-aspects";
            default = { };
            type = lib.types.submodule (
              { config, ... }:
              {
                freeformType = lib.types.lazyAttrsOf (
                  lib.types.either (aspectType (cnf // { aspectChain = (cnf.aspectChain or [ ]) ++ [ name ]; })) (
                    aspectSubmodule (cnf // { aspectChain = (cnf.aspectChain or [ ]) ++ [ name ]; })
                  )
                );
                config._module.args.aspects = config;
              }
            );
          };

          __functor = lib.mkOption {
            internal = true;
            visible = false;
            description = "Functor to default provider";
            type = functorType;
            default =
              let
                defaultFunctor = aspect: { class, aspect-chain }: if true then aspect else class aspect-chain;
              in
              cnf.defaultFunctor or defaultFunctor;
          };

          modules = mkInternal "resolved modules from this aspect" ignoredType (
            _: lib.mapAttrs (class: _: config.resolve { inherit class; }) config
          );

          resolve = mkInternal "function to resolve a module from this aspect" ignoredType (
            _:
            {
              class,
              aspect-chain ? [ ],
            }:
            resolve class aspect-chain (config {
              inherit class aspect-chain;
            })
          );
        };
      }
    );

  aspectsType =
    cnf:
    lib.types.submodule (
      { config, ... }:
      {
        freeformType = lib.types.lazyAttrsOf (aspectType cnf);
        config._module.args.aspects = config;
      }
    );

in
{
  inherit
    aspectsType
    aspectSubmodule
    aspectType
    isModuleFn
    ;
}
