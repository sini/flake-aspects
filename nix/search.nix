# nix/search.nix — Palmer §3 Search monad. Zero dependencies.
let
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

  on = key: fn: state: {
    inherit (state) index results;
    continuations = state.continuations ++ [
      {
        inherit key fn;
        processed = 0;
      }
    ];
  };

  # Private: list drop without lib dependency.
  drop =
    n: list:
    let
      len = builtins.length list;
    in
    if n >= len then [ ] else builtins.genList (i: builtins.elemAt list (i + n)) (len - n);

  # Private: dedup intensional continuations (Palmer §3).
  # Two continuations with the same fn.key (from mkIntensional) watching
  # the same index key are considered identical. Non-intensional fns pass through.
  dedupContinuations =
    conts:
    let
      keyOf = c: if c.fn ? key then "${c.key}:${c.fn.key}" else null;
      go =
        seen: rest:
        if rest == [ ] then
          [ ]
        else
          let
            c = builtins.head rest;
            k = keyOf c;
            tail = builtins.tail rest;
          in
          if k != null && seen ? ${k} then
            go seen tail
          else
            [ c ] ++ go (if k != null then seen // { ${k} = true; } else seen) tail;
    in
    go { } conts;

  converge =
    state:
    let
      step =
        state:
        let
          deduped = dedupContinuations state.continuations;
          fired =
            builtins.foldl'
              (
                acc: cont:
                let
                  values = acc.state.index.${cont.key} or [ ];
                  unprocessed = drop cont.processed values;
                  result = builtins.foldl' (s: v: cont.fn v s) acc.state unprocessed;
                  newProcessed = builtins.length values;
                in
                {
                  state = result;
                  rebuilt = acc.rebuilt ++ [
                    {
                      inherit (cont) key fn;
                      processed = newProcessed;
                    }
                  ];
                  anyFired = acc.anyFired || (builtins.length unprocessed > 0);
                }
              )
              {
                state = state // {
                  continuations = [ ];
                };
                rebuilt = [ ];
                anyFired = false;
              }
              deduped;
          allContinuations = dedupContinuations (fired.rebuilt ++ fired.state.continuations);
        in
        {
          state = fired.state // {
            continuations = allContinuations;
          };
          anyFired = fired.anyFired;
        };
      iterate =
        n: state:
        if n <= 0 then
          throw "search: converge exceeded 1000 iterations — likely a non-terminating continuation"
        else
          let
            r = step state;
          in
          if r.anyFired then iterate (n - 1) r.state else r.state;
    in
    iterate 1000 state;

in
{
  inherit
    empty
    lookup
    has
    insert
    emit
    foldl
    on
    converge
    ;
}
