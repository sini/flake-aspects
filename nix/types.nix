lib:
let
  resolve = import ./resolve.nix lib;
  identity = import ./identity.nix lib;

  ignoredType = lib.types.mkOptionType {
    name = "ignored type";
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

  # Palmer's flat type. One type, dispatch in merge, no recursive type construction.
  aspectType =
    cnf:
    lib.types.mkOptionType {
      name = "aspect";
      check = v: builtins.isAttrs v || builtins.isFunction v;
      merge =
        loc: defs:
        let
          d = builtins.head defs;
          v = d.value;
        in
        if builtins.length defs == 1 then
          if builtins.isAttrs v && (v.__isWrappedFn or false) then
            v
          else if builtins.isFunction v then
            let
              args = builtins.functionArgs v;
            in
            if args ? lib || args ? config || args ? options || args ? aspect then
              (aspectSubmodule cnf).merge loc defs
            else
              (lib.types.functionTo (aspectSubmodule cnf)).merge (loc ++ [ "<function body>" ]) defs
              // {
                __isWrappedFn = true;
              }
          else
            (aspectSubmodule cnf).merge loc defs
        else
          (aspectSubmodule cnf).merge loc (
            map (
              def:
              if builtins.isFunction def.value then
                def
                // {
                  value = {
                    includes = [ def.value ];
                  };
                }
              else
                def
            ) defs
          );
    };

  aspectOrFn = cnf: lib.types.either (aspectType cnf) (aspectSubmodule cnf);

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

          # Palmer's `identify` eliminator — intrinsic identity
          key = mkInternal "aspect identity key" lib.types.str (_: identity.key config);

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

          modules = mkInternal "resolved modules" ignoredType (
            _: lib.mapAttrs (class: _: config.resolve { inherit class; }) config
          );

          resolve = mkInternal "resolve for class" ignoredType (
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

  # Palmer's intensional function constructor (§2.2).
  # Wraps a function as inspectable, comparable first-order data.
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
