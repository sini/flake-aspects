{ identity, ... }:
{
  flake.tests."test identity key from nested aspect" = {
    expr = identity.key {
      name = "baz";
      meta.aspect-chain = [
        "foo"
        "bar"
      ];
    };
    expected = "foo/bar/baz";
  };

  flake.tests."test identity key from root aspect" = {
    expr = identity.key {
      name = "myaspect";
      meta.aspect-chain = [ ];
    };
    expected = "myaspect";
  };

  flake.tests."test identity key from anon aspect" = {
    expr = identity.key { meta.aspect-chain = [ "parent" ]; };
    expected = "parent/<anon>";
  };

  flake.tests."test identity aspectPath" = {
    expr = identity.aspectPath {
      name = "child";
      meta.aspect-chain = [
        "root"
        "mid"
      ];
    };
    expected = [
      "root"
      "mid"
      "child"
    ];
  };
}
