{ search, mkIntensional, ... }:
{
  # Basic: continuation fires on values already in the index
  flake.tests."test search converge basic" = {
    expr =
      let
        s0 = search.insert "k" "v1" search.empty;
        s1 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:v1" ];
  };

  # Multi-round: continuation A inserts, triggering continuation B
  flake.tests."test search converge multi-round" = {
    expr =
      let
        s0 = search.insert "trigger" "go" search.empty;
        # A watches "trigger", inserts into "data"
        s1 = search.on "trigger" (_v: s: search.insert "data" "from-A" s) s0;
        # B watches "data", emits what it sees
        s2 = search.on "data" (v: s: search.emit [ "B-saw:${v}" ] s) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "B-saw:from-A" ];
  };

  # Stability: converge with no unprocessed values is a no-op
  flake.tests."test search converge stability" = {
    expr =
      let
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" (v: s: search.emit [ v ] s) s0;
        first = search.converge s1;
        # Converge again — no new values, should be stable
        second = search.converge first;
      in
      {
        firstResults = first.results;
        secondResults = second.results;
      };
    expected = {
      firstResults = [ "v" ];
      secondResults = [ "v" ];
    };
  };

  # Unwatched key: continuation watching absent key is no-op
  flake.tests."test search converge unwatched key" = {
    expr =
      let
        s0 = search.insert "other" "v" search.empty;
        s1 = search.on "missing" (_v: s: search.emit [ "should-not-fire" ] s) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ ];
  };

  # Dynamic registration: on called during convergence fires next round
  flake.tests."test search converge dynamic registration" = {
    expr =
      let
        s0 = search.insert "phase1" "go" search.empty;
        s1 = search.insert "phase2" "data" s0;
        # First continuation watches phase1, registers a new continuation on phase2
        s2 = search.on "phase1" (
          _v: s: search.on "phase2" (v2: s2: search.emit [ "dynamic:${v2}" ] s2) s
        ) s1;
        final = search.converge s2;
      in
      final.results;
    expected = [ "dynamic:data" ];
  };

  # Intensional dedup: duplicate mkIntensional continuations fire once
  flake.tests."test search converge intensional dedup" = {
    expr =
      let
        counter = mkIntensional "my-counter" { } (v: s: search.emit [ "counted:${v}" ] s);
        s0 = search.insert "k" "v" search.empty;
        # Register same intensional continuation twice
        s1 = search.on "k" counter s0;
        s2 = search.on "k" counter s1;
        final = search.converge s2;
      in
      final.results;
    # Only one "counted:v" — the duplicate was deduped
    expected = [ "counted:v" ];
  };

  # Converge on empty state is identity
  flake.tests."test search converge empty" = {
    expr = search.converge search.empty;
    expected = search.empty;
  };

  # Bounded self-inserting continuation terminates
  flake.tests."test search converge bounded self-insert" = {
    expr =
      let
        # Continuation inserts "done" on first fire, then stops
        s0 = search.insert "k" "start" search.empty;
        s1 = search.on "k" (
          v: s:
          if v == "start" then
            search.insert "k" "done" (search.emit [ "processed:${v}" ] s)
          else
            search.emit [ "processed:${v}" ] s
        ) s0;
        final = search.converge s1;
      in
      final.results;
    expected = [
      "processed:start"
      "processed:done"
    ];
  };

  # on registered before insert — the primary den use case
  # (register policy watchers, then populate context)
  flake.tests."test search converge on before insert" = {
    expr =
      let
        s0 = search.on "k" (v: s: search.emit [ "saw:${v}" ] s) search.empty;
        s1 = search.insert "k" "late-arrival" s0;
        final = search.converge s1;
      in
      final.results;
    expected = [ "saw:late-arrival" ];
  };

  # Non-intensional duplicate continuations are NOT deduped — both fire
  flake.tests."test search converge non-intensional duplicates fire independently" = {
    expr =
      let
        fn = v: s: search.emit [ "fired:${v}" ] s;
        s0 = search.insert "k" "v" search.empty;
        s1 = search.on "k" fn s0;
        s2 = search.on "k" fn s1;
        final = search.converge s2;
      in
      final.results;
    # Both fire — plain functions have no identity for dedup
    expected = [
      "fired:v"
      "fired:v"
    ];
  };
}
