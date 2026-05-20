lib:
let
  aspectPath = a: (a.meta.aspect-chain or [ ]) ++ [ (a.name or "<anon>") ];

  pathKey = path: lib.concatStringsSep "/" path;
in
{
  inherit aspectPath pathKey;

  key = a: pathKey (aspectPath a);

  structuralKeysSet = lib.genAttrs [
    "name"
    "description"
    "meta"
    "includes"
    "provides"
    "__functor"
    "__functionArgs"
    "__fn"
    "__args"
    "__isParametric"
    "_module"
    "_"
  ] (_: true);
}
