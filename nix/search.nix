# nix/search.nix — Palmer §3 Search monad. Zero dependencies.
rec {
  empty = {
    index = { };
    results = [ ];
    continuations = [ ];
  };

  lookup = key: state: state.index.${key} or [ ];

  has = key: state: state.index ? ${key};

  insert = key: value: state: {
    inherit (state) results continuations;
    index = state.index // {
      ${key} = (state.index.${key} or [ ]) ++ [ value ];
    };
  };

  emit = items: state: {
    inherit (state) index continuations;
    results = state.results ++ items;
  };

  foldl = f: builtins.foldl' f;
}
