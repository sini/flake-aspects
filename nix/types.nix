lib:
let
  resolve = import ./resolve.nix lib;
  identity = import ./identity.nix lib;

  # Type for internal computed options — merges to null, apply overrides value.
  internalType = lib.types.mkOptionType {
    name = "internal";
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

  isSubmoduleFn =
    v:
    let
      args = builtins.functionArgs v;
    in
    args ? lib || args ? config || args ? options || args ? aspect;

  # Palmer's flat type. One type, dispatch in merge, no recursive type construction.
  aspectType =
    cnf:
    lib.types.mkOptionType {
      name = "aspect";
      check = _: true;
      merge =
        loc: defs:
        if builtins.length defs != 1 then
          # Multi-def: check if all primitives (lists, strings, etc.)
          if builtins.all (d: !(builtins.isAttrs d.value) && !(builtins.isFunction d.value)) defs then
            # All primitives — mkMerge so the option type decides how to combine
            lib.mkMerge (map (d: d.value) defs)
          else
            # Has attrsets/functions — coerce functions, merge as submodule
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
            )
        else
          let
            v = (builtins.head defs).value;
          in
          # Wrapped fn — passthrough
          if builtins.isAttrs v && (v.__isWrappedFn or false) then
            v
          # Submodule fn — direct eval (needs _module.args)
          else if builtins.isFunction v && isSubmoduleFn v then
            (aspectSubmodule cnf).merge loc defs
          # Parametric fn — defunctionalize (functionTo types the return value)
          else if builtins.isFunction v then
            (lib.types.functionTo (aspectSubmodule cnf)).merge (loc ++ [ "<function body>" ]) defs
            // {
              __isWrappedFn = true;
            }
          # Attrset → always merge as submodule (gets identity, structural keys)
          else if builtins.isAttrs v then
            (aspectSubmodule cnf).merge loc defs
          # Primitive (list, string, bool, etc.) → pass through raw
          else
            (lib.last defs).value;
    };

  # Recursion-safe binding: either doesn't force subtypes during construction.
  aspectOrFn = cnf: lib.types.either (aspectType cnf) (aspectSubmodule cnf);

  aspectSubmodule =
    cnf:
    lib.types.submodule (
      { name, config, ... }:
      {
        freeformType = lib.types.lazyAttrsOf (aspectType cnf);
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

          key = mkInternal "identity key" lib.types.str (_: identity.key config);

          meta = lib.mkOption {
            description = "Aspect metadata";
            default = { };
            type = lib.types.submodule {
              freeformType = lib.types.lazyAttrsOf lib.types.raw;
              options.aspect-chain = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = cnf.aspectChain or [ ];
              };
            };
          };

          includes = lib.mkOption {
            description = "Aspects to include";
            type = lib.types.listOf (aspectOrFn cnf);
            default = [ ];
          };

          provides = lib.mkOption {
            description = "Named sub-aspects";
            default = { };
            type = lib.types.submodule (
              { config, ... }:
              {
                freeformType = lib.types.lazyAttrsOf (
                  aspectOrFn (cnf // { aspectChain = (cnf.aspectChain or [ ]) ++ [ name ]; })
                );
                config._module.args.aspects = config;
              }
            );
          };

          __functor = lib.mkOption {
            internal = true;
            visible = false;
            type = functorType;
            default =
              let
                defaultFunctor = aspect: { class, aspect-chain }: if true then aspect else class aspect-chain;
              in
              cnf.defaultFunctor or defaultFunctor;
          };

          modules = mkInternal "resolved modules" internalType (
            _: lib.mapAttrs (class: _: config.resolve { inherit class; }) config
          );

          resolve = mkInternal "resolve for class" internalType (
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

  mkIntensional = name: closure: fn: {
    inherit name fn closure;
    key = "${name}:${builtins.hashString "sha256" (builtins.toJSON closure)}";
    __functor = self: self.fn;
  };

in
{
  inherit
    aspectsType
    aspectSubmodule
    aspectType
    mkIntensional
    ;
}
