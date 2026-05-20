lib:
let
  identity = import ./identity.nix lib;

  isMeaningfulName =
    name: name != "<anon>" && name != "<function body>" && !(lib.hasPrefix "[definition " name);

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
      dedupKey =
        if isMeaningfulName name && !(lib.hasPrefix "<" name && lib.hasSuffix ">" name) then
          identity.key provided
        else
          null;
      alreadySeen = dedupKey != null && seen ? ${dedupKey};
      config = provided.${class} or { };
      includes = provided.includes or [ ];
      newSeen = if dedupKey != null then seen // { ${dedupKey} = true; } else seen;
      resolvedIncludes = lib.map (include class (aspect-chain ++ [ provided ]) newSeen) includes;
    in
    {
      imports = lib.flatten [
        (lib.optional (!alreadySeen) config)
        resolvedIncludes
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
