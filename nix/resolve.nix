lib:
let
  identity = import ./identity.nix lib;

  structuralKeys = builtins.attrNames identity.structuralKeysSet;

  # Recursively strip aspect structural keys from class content.
  # Returns a list: [content] ++ user-imports (from the aspectSubmodule).
  extractClass =
    raw:
    if builtins.isAttrs raw && builtins.any (k: raw ? ${k}) structuralKeys then
      let
        stripped = lib.mapAttrs (_: v: extractClassSingle v) (builtins.removeAttrs raw structuralKeys);
        userImports = raw.imports or [ ];
      in
      [ stripped ] ++ userImports
    else
      [ raw ];

  extractClassSingle =
    v:
    if builtins.isAttrs v && builtins.any (k: v ? ${k}) structuralKeys then
      lib.mapAttrs (_: extractClassSingle) (builtins.removeAttrs v structuralKeys)
    else
      v;

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
