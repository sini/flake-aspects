lib:
let
  identity = import ./identity.nix lib;

  structuralKeys = builtins.attrNames identity.structuralKeysSet;

  isAspectValue = v: builtins.isAttrs v && v ? name && v ? includes;

  # Strip aspect structure recursively from nested values.
  # Lorenzen's eval-one can't apply here because the NixOS module system
  # needs clean values (no structural keys) at all depths.
  extractClassSingle =
    v:
    if isAspectValue v then
      lib.mapAttrs (_: extractClassSingle) (builtins.removeAttrs v structuralKeys)
    else if builtins.isAttrs v && (v.__isWrappedFn or false) then
      args:
      let
        result = v args;
      in
      if isAspectValue result then builtins.removeAttrs result structuralKeys else result
    else
      v;

  extractClass =
    raw:
    if isAspectValue raw then
      [ (lib.mapAttrs (_: extractClassSingle) (builtins.removeAttrs raw structuralKeys)) ]
    else
      [ raw ];

  # Palmer §3: fold-based collect threads seen set across sibling includes,
  # deduplicating diamond dependencies where the same aspect is reached
  # via parallel include paths.
  collect =
    class: aspect-chain: seen: provided:
    let
      name = provided.name or "<anon>";
      isSynthetic = lib.hasPrefix "<" name && lib.hasSuffix ">" name;
      dedupKey = if identity.isMeaningfulName name && !isSynthetic then identity.key provided else null;
      alreadySeen = dedupKey != null && seen ? ${dedupKey};
      newSeen = if dedupKey != null then seen // { ${dedupKey} = true; } else seen;
      childChain = aspect-chain ++ [ provided ];
      # Fold over includes, threading seen across siblings for cross-branch dedup.
      collectIncludes =
        builtins.foldl'
          (
            acc: provider:
            let
              provided' =
                if lib.isFunction provider then
                  provider {
                    inherit class;
                    aspect-chain = childChain;
                  }
                else
                  provider;
              result = collect class childChain acc.seen provided';
            in
            {
              seen = acc.seen // result.seen;
              modules = acc.modules ++ result.modules;
            }
          )
          {
            seen = newSeen;
            modules = [ ];
          }
          (provided.includes or [ ]);
    in
    {
      seen = collectIncludes.seen;
      modules = lib.flatten [
        (lib.optionals (!alreadySeen) (extractClass (provided.${class} or { })))
        collectIncludes.modules
      ];
    };

  # Single wrap at the top level (Lorenzen: flat collect, single wrap).
  # collect eagerly flattens the entire include tree. Lorenzen §2.4's
  # eval-one (partial forcing) doesn't apply — the NixOS module system
  # requires fully-stripped values at all depths. Nix's native thunk
  # laziness provides deferred evaluation at the attribute access level:
  # resolve is only called when a class's modules are actually needed.
  resolve =
    class: aspect-chain: aspect:
    let
      provided =
        if lib.isFunction aspect then
          aspect {
            inherit class;
            aspect-chain = aspect-chain;
          }
        else
          aspect;
    in
    {
      imports = (collect class aspect-chain { } provided).modules;
    };
in
resolve
