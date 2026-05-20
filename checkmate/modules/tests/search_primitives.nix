{ search, ... }:
{
  flake.tests."test search insert lookup round-trip" = {
    expr = search.lookup "k" (search.insert "k" "v" search.empty);
    expected = [ "v" ];
  };

  flake.tests."test search insert monotonicity" = {
    expr =
      let
        s1 = search.insert "k" "a" search.empty;
        s2 = search.insert "k" "b" s1;
      in
      search.lookup "k" s2;
    expected = [
      "a"
      "b"
    ];
  };

  flake.tests."test search has after insert" = {
    expr = {
      before = search.has "k" search.empty;
      after = search.has "k" (search.insert "k" "v" search.empty);
    };
    expected = {
      before = false;
      after = true;
    };
  };

  flake.tests."test search emit accumulation" = {
    expr =
      let
        s1 = search.emit [
          "a"
          "b"
        ] search.empty;
        s2 = search.emit [ "c" ] s1;
      in
      s2.results;
    expected = [
      "a"
      "b"
      "c"
    ];
  };

  flake.tests."test search foldl state threading" = {
    expr =
      let
        items = [
          "a"
          "b"
          "c"
        ];
        final = search.foldl (
          acc: item: search.insert item true (search.emit [ item ] acc)
        ) search.empty items;
      in
      {
        results = final.results;
        hasA = search.has "a" final;
        hasB = search.has "b" final;
        hasC = search.has "c" final;
      };
    expected = {
      results = [
        "a"
        "b"
        "c"
      ];
      hasA = true;
      hasB = true;
      hasC = true;
    };
  };

  flake.tests."test search insert duplicate values accumulate" = {
    expr =
      let
        s1 = search.insert "k" "v" search.empty;
        s2 = search.insert "k" "v" s1;
      in
      search.lookup "k" s2;
    expected = [
      "v"
      "v"
    ];
  };

  flake.tests."test search lookup absent key" = {
    expr = search.lookup "nonexistent" search.empty;
    expected = [ ];
  };

  flake.tests."test search emit empty list" = {
    expr = (search.emit [ ] search.empty).results;
    expected = [ ];
  };
}
