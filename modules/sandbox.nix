{ lib
, pkgs
, ...
} @ args:

let
  backend =
    if pkgs.stdenv.hostPlatform.isDarwin then
      ./sandbox-darwin.nix
    else if pkgs.stdenv.hostPlatform.isLinux then
      ./sandbox-linux.nix
    else
      throw "termcheck does not support ${pkgs.stdenv.hostPlatform.system}";
in
pkgs.callPackage backend (builtins.removeAttrs args [ "lib" "pkgs" ])
