{
  description = "TermCheck: Formal access rules for shells and programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" ];

    perSystem = { pkgs, ... }: {
      packages.default = pkgs.callPackage ./modules/sandbox.nix {
        policy = import ./example-policy.nix;
      };
    };
  };
}

