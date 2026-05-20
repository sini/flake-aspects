lib:
let
  aspectPath = a: (a.meta.aspect-chain or [ ]) ++ [ (a.name or "<anon>") ];

  pathKey = path: lib.concatStringsSep "/" path;
in
{
  inherit aspectPath pathKey;

  key = a: pathKey (aspectPath a);

  # Structural keys — derived from aspectSubmodule's declared options + internal attrs.
  # If aspectSubmodule gains a new option, add it here.
  structuralKeysSet = lib.genAttrs [
    # aspectSubmodule declared options
    "name"
    "description"
    "meta"
    "includes"
    "provides"
    "__functor"
    # computed/internal options
    "modules"
    "resolve"
    "key"
    # module system internals
    "_module"
    "_"
    # wrapper tags
    "__isWrappedFn"
    "__functionArgs"
  ] (_: true);
}
