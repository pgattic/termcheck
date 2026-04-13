{ lib
, pkgs
, policy
, name ? "launch-sandbox"
, ...
}:

let
  defaultPackageNames = [ "coreutils" "bash" "python3" ];

  filesystem = policy.filesystem or {};
  network = policy.network or {};
  packages = policy.packages or {};

  readOnlyPaths = filesystem.readOnly or [];
  readWritePaths = filesystem.readWrite or [];
  networkEnabled = network.enable or false;
  allowedHosts = network.allowedHosts or [];
  allowDefaultPackages = packages.allowDefaults or true;
  allowedPackageNames = packages.allowed or [];
  command = policy.command or [ "bash" ];

  configuredPackageNames =
    lib.unique (allowedPackageNames ++ lib.optionals allowDefaultPackages defaultPackageNames);

  hasPackage = name: lib.hasAttr name pkgs;
  unknownPackages = builtins.filter (name: !(hasPackage name)) configuredPackageNames;

  allowedPackages = map (packageName: pkgs.${packageName}) configuredPackageNames;
  sandboxPath = lib.makeBinPath allowedPackages;

  netFlag = if networkEnabled then "--share-net" else "--unshare-net";

  bindReadOnly = path: ''
    add_mount --ro-bind ${lib.escapeShellArg path}
  '';

  bindReadWrite = path: ''
    add_mount --bind ${lib.escapeShellArg path}
  '';
in
assert lib.asserts.assertMsg (builtins.isAttrs policy)
  "termcheck policy must be an attribute set";
assert lib.asserts.assertMsg (builtins.isList readOnlyPaths)
  "termcheck policy filesystem.readOnly must be a list";
assert lib.asserts.assertMsg (builtins.isList readWritePaths)
  "termcheck policy filesystem.readWrite must be a list";
assert lib.asserts.assertMsg (builtins.all builtins.isString (readOnlyPaths ++ readWritePaths))
  "termcheck policy filesystem paths must all be strings";
assert lib.asserts.assertMsg (builtins.isBool networkEnabled)
  "termcheck policy network.enable must be a boolean";
assert lib.asserts.assertMsg (allowedHosts == [])
  "termcheck policy network.allowedHosts is not implemented yet; use [] or network.enable = true for unrestricted host networking";
assert lib.asserts.assertMsg (builtins.isBool allowDefaultPackages)
  "termcheck policy packages.allowDefaults must be a boolean";
assert lib.asserts.assertMsg (builtins.isList allowedPackageNames && builtins.all builtins.isString allowedPackageNames)
  "termcheck policy packages.allowed must be a list of nixpkgs package names";
assert lib.asserts.assertMsg (unknownPackages == [])
  "termcheck policy references unknown nixpkgs packages: ${lib.concatStringsSep ", " unknownPackages}";
assert lib.asserts.assertMsg (builtins.isList command && command != [] && builtins.all builtins.isString command)
  "termcheck policy command must be a non-empty list of strings";
pkgs.writeShellScriptBin name ''
  set -euo pipefail

  # Resolve repo root at runtime
  REPO_ROOT=$(${lib.getExe pkgs.git} -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$REPO_ROOT" ]; then
    echo "error: not inside a git repository" >&2
    exit 1
  fi

  # Resolve policy paths. Absolute paths pass through, ~/ paths use the
  # invoking user's home, and everything else is repo-relative.
  resolve_path() {
    local p="$1"

    if [[ "$p" == /* ]]; then
      echo "$p"
    elif [[ "$p" == "~" ]]; then
      echo "''${HOME:?policy path uses ~ but HOME is not set}"
    elif [[ "$p" == "~/"* ]]; then
      echo "''${HOME:?policy path uses ~ but HOME is not set}/''${p#\~/}"
    elif [[ "$p" == "~"* ]]; then
      echo "error: policy path uses unsupported home form: $p" >&2
      exit 1
    elif [[ "$p" == ./* ]]; then
      echo "$REPO_ROOT/''${p#./}"
    else
      echo "$REPO_ROOT/$p"
    fi
  }

  add_mount() {
    local mode="$1"
    local policy_path="$2"
    local resolved_path

    resolved_path="$(resolve_path "$policy_path")"
    if [ ! -e "$resolved_path" ]; then
      echo "error: policy path does not exist: $policy_path -> $resolved_path" >&2
      exit 1
    fi

    MOUNTS+=("$mode" "$resolved_path" "$resolved_path")
  }

  # Build bind mount args dynamically from policy
  MOUNTS=()
  ${lib.concatMapStrings bindReadOnly readOnlyPaths}
  ${lib.concatMapStrings bindReadWrite readWritePaths}

  exec ${pkgs.bubblewrap}/bin/bwrap \
    --unshare-all \
    --new-session \
    --die-with-parent \
    --ro-bind /nix /nix \
    --tmpfs /tmp \
    --proc /proc \
    --dev /dev \
    ${netFlag} \
    "''${MOUNTS[@]}" \
    --setenv PATH ${lib.escapeShellArg sandboxPath} \
    --setenv REPO_ROOT "$REPO_ROOT" \
    -- ${lib.escapeShellArgs command}
''
