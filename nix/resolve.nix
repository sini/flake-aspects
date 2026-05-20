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

  # Collect imports flat — no { imports = [...] } wrapping per level.
  # Returns a flat list of modules, not nested { imports } attrsets.
  include =
    class: aspect-chain: seen: provider:
    let
      provided = if lib.isFunction provider then provider { inherit aspect-chain class; } else provider;
    in
    collect class aspect-chain seen provided;

  collect =
    class: aspect-chain: seen: provided:
    let
      name = provided.name or "<anon>";
      isSynthetic = lib.hasPrefix "<" name && lib.hasSuffix ">" name;
      dedupKey = if identity.isMeaningfulName name && !isSynthetic then identity.key provided else null;
      alreadySeen = dedupKey != null && seen ? ${dedupKey};
      newSeen = if dedupKey != null then seen // { ${dedupKey} = true; } else seen;
    in
    lib.flatten [
      (lib.optionals (!alreadySeen) (extractClass (provided.${class} or { })))
      (lib.map (include class (aspect-chain ++ [ provided ]) newSeen) (provided.includes or [ ]))
    ];

  # Single wrap at the top level.
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
      imports = collect class aspect-chain { } provided;
    };
in
resolve
