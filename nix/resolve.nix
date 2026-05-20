lib:
let
  search = import ./search.nix;
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

  dedupKeyOf =
    provided:
    let
      name = provided.name or "<anon>";
      isSynthetic = lib.hasPrefix "<" name && lib.hasSuffix ">" name;
    in
    if identity.isMeaningfulName name && !isSynthetic then identity.key provided else null;

  coerce = provider: ctx: if lib.isFunction provider then provider ctx else provider;

  # Palmer §3: fold-based collect threads seen set across sibling includes,
  # deduplicating diamond dependencies where the same aspect is reached
  # via parallel include paths.
  collect =
    class: aspect-chain: state: provided:
    let
      key = dedupKeyOf provided;
      alreadySeen = key != null && search.has key state;
      state' = if key != null then search.insert key provided state else state;
      state'' =
        if !alreadySeen then search.emit (extractClass (provided.${class} or { })) state' else state';
      childChain = aspect-chain ++ [ provided ];
    in
    search.foldl (
      acc: provider:
      let
        provided' = coerce provider {
          inherit class;
          aspect-chain = childChain;
        };
      in
      collect class childChain acc provided'
    ) state'' (provided.includes or [ ]);

  # Single wrap at the top level (Lorenzen: flat collect, single wrap).
  # collect eagerly flattens the entire include tree. Lorenzen §2.4's
  # eval-one (partial forcing) doesn't apply — the NixOS module system
  # requires fully-stripped values at all depths. Nix's native thunk
  # laziness provides deferred evaluation at the attribute access level:
  # resolve is only called when a class's modules are actually needed.
  resolve =
    class: aspect-chain: aspect:
    let
      provided = coerce aspect {
        inherit class;
        aspect-chain = aspect-chain;
      };
      final = collect class aspect-chain search.empty provided;
    in
    {
      imports = final.results;
    };
in
resolve
