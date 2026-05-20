lib:
let
  identity = import ./identity.nix lib;

  structuralKeys = builtins.attrNames identity.structuralKeysSet;

  isAspectValue = v: builtins.isAttrs v && v ? name && v ? includes;

  # Recursively strip aspect structure from values.
  extractClassSingle =
    v:
    if isAspectValue v then
      lib.mapAttrs (_: extractClassSingle) (builtins.removeAttrs v structuralKeys)
    else if builtins.isAttrs v && (v.__isWrappedFn or false) then
      # Wrapped module function — create a new function that calls the
      # wrapper and strips aspect keys from the result, preserving imports.
      args:
      let
        result = v args;
      in
      if isAspectValue result then builtins.removeAttrs result structuralKeys else result
    else
      v;

  # Extract class content from a freeform value.
  # Aspect values → strip structural keys, return as module list.
  # Non-aspect → return as-is in a list.
  extractClass =
    raw:
    if isAspectValue raw then
      [ (lib.mapAttrs (_: extractClassSingle) (builtins.removeAttrs raw structuralKeys)) ]
    else
      [ raw ];

  include =
    class: aspect-chain: seen: provider:
    let
      provided = if lib.isFunction provider then provider { inherit aspect-chain class; } else provider;
    in
    inner class aspect-chain seen provided;

  inner =
    class: aspect-chain: seen: provided:
    let
      name = provided.name or "<anon>";
      isSynthetic = lib.hasPrefix "<" name && lib.hasSuffix ">" name;
      dedupKey = if identity.isMeaningfulName name && !isSynthetic then identity.key provided else null;
      alreadySeen = dedupKey != null && seen ? ${dedupKey};
      newSeen = if dedupKey != null then seen // { ${dedupKey} = true; } else seen;
    in
    {
      imports = lib.flatten [
        (lib.optionals (!alreadySeen) (extractClass (provided.${class} or { })))
        (lib.map (include class (aspect-chain ++ [ provided ]) newSeen) (provided.includes or [ ]))
      ];
    };

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
    inner class aspect-chain { } provided;
in
resolve
