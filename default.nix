{
  pkgs ? import <nixpkgs> { },
  ...
}:
import ./nix/lib.nix { lib = pkgs.lib; }
