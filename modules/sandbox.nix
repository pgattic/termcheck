{ lib, pkgs, policy, ... }: let
  # Build a minimal PATH containing only allowed commands
  allowedPkgs = map (name: pkgs.${name}) policy.packages;
  sandboxPath = pkgs.lib.makeBinPath (allowedPkgs ++ [ pkgs.bubblewrap ]);

  # Build the filesystem bind-mount arguments
  fsMounts =
    (map (p: "--ro-bind ${p} ${p}") policy.filesystem.readOnly) ++
    (map (p: "--bind ${p} ${p}") policy.filesystem.readWrite);

  # Network flag
  netFlag = if policy.network.enable then "" else "--unshare-net";

  # Assemble the bwrap command
  bwrapCmd = pkgs.lib.concatStringsSep " " ([
    "${pkgs.bubblewrap}/bin/bwrap"
    "--unshare-user"
    "--unshare-pid"
    "--unshare-ipc"
    "--unshare-uts"
    "--new-session"
    "--die-with-parent"
    "--ro-bind /nix /nix"   # Nix store always needed
    "--tmpfs /tmp"
    "--proc /proc"
    "--dev /dev"
    netFlag
  ] ++ fsMounts ++ [
    "--setenv PATH ${sandboxPath}"
    "-- ${lib.escapeShellArgs policy.command}"
  ]);
in pkgs.writeShellScriptBin "launch-sandbox" ''
  exec ${bwrapCmd}
''

