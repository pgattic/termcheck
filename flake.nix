{
  description = "TermCheck: Formal access rules for shells and programs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" ];

    flake.lib.mkSandbox = { pkgs, policy, name ? "launch-sandbox" }:
      pkgs.callPackage ./modules/sandbox.nix {
        inherit name policy;
      };

    perSystem = { pkgs, ... }:
      let
        examplePolicy = import ./example-policy.nix;
        launchSandbox = pkgs.callPackage ./modules/sandbox.nix {
          policy = examplePolicy;
        };
      in
      {
        packages.default = launchSandbox;
        packages.launch-sandbox = launchSandbox;

        apps.default = {
          type = "app";
          program = "${launchSandbox}/bin/launch-sandbox";
          meta.description = "Run the example TermCheck sandbox";
        };
        apps.launch-sandbox = {
          type = "app";
          program = "${launchSandbox}/bin/launch-sandbox";
          meta.description = "Run the example TermCheck sandbox";
        };

        checks.launcher-shell-syntax = pkgs.runCommand "launch-sandbox-shell-syntax" {} ''
          ${pkgs.bash}/bin/bash -n ${launchSandbox}/bin/launch-sandbox
          touch $out
        '';
      };
  };
}
