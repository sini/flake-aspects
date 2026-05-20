lib:
let
  aspectPath = a: (a.meta.aspect-chain or [ ]) ++ [ (a.name or "<anon>") ];

  pathKey = path: lib.concatStringsSep "/" path;

  isMeaningfulName =
    name: name != "<anon>" && name != "<function body>" && !(lib.hasPrefix "[definition " name);
in
{
  inherit aspectPath pathKey isMeaningfulName;

  key = a: pathKey (aspectPath a);

  # Keys that are structural to aspects, never class content.
  structuralKeysSet = lib.genAttrs [
    "name"
    "description"
    "meta"
    "includes"
    "provides"
    "key"
    "modules"
    "resolve"
    "imports"
    "__functor"
    "__functionArgs"
    "__isWrappedFn"
    "_module"
    "_"
  ] (_: true);
}
