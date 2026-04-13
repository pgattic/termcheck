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

  bindReadOnly = path: ''
    add_profile_path read-only ${lib.escapeShellArg path}
  '';

  bindReadWrite = path: ''
    add_profile_path read-write ${lib.escapeShellArg path}
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
  "termcheck policy network.allowedHosts is not implemented on Darwin yet; use []";
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

  if [ ! -x /usr/bin/sandbox-exec ]; then
    echo "error: /usr/bin/sandbox-exec is required for the Darwin backend" >&2
    exit 1
  fi

  REPO_ROOT=$(${lib.getExe pkgs.git} -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$REPO_ROOT" ]; then
    echo "error: not inside a git repository" >&2
    exit 1
  fi

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

  sbpl_string() {
    local s="$1"
    s="''${s//\\/\\\\}"
    s="''${s//\"/\\\"}"
    printf '"%s"' "$s"
  }

  add_profile_path() {
    local mode="$1"
    local policy_path="$2"
    local resolved_path
    local path_filter

    resolved_path="$(resolve_path "$policy_path")"
    if [ ! -e "$resolved_path" ]; then
      echo "error: policy path does not exist: $policy_path -> $resolved_path" >&2
      exit 1
    fi

    if [ -d "$resolved_path" ]; then
      path_filter="(subpath $(sbpl_string "$resolved_path"))"
    else
      path_filter="(literal $(sbpl_string "$resolved_path"))"
    fi

    PROFILE_RULES+=("(allow file-read* $path_filter)")
    if [ "$mode" = read-write ]; then
      PROFILE_RULES+=("(allow file-write* $path_filter)")
    fi
  }

  PROFILE_RULES=(
    "(version 1)"
    "(deny default)"
    "(allow process*)"
    "(allow sysctl-read)"
    "(allow mach-lookup)"
    "(allow file-read-metadata (literal \"/\") (subpath \"/nix\") (subpath \"/dev\") (subpath \"/System\") (subpath \"/Library\") (subpath \"/usr/lib\") (subpath \"/private/etc\") (subpath \"/etc\"))"
    "(allow file-read* (subpath \"/nix\") (subpath \"/dev\") (subpath \"/System/Library\") (subpath \"/usr/lib\") (subpath \"/private/etc\") (subpath \"/etc\"))"
  )

  ${lib.optionalString networkEnabled ''
    PROFILE_RULES+=("(allow network*)")
  ''}

  ${lib.concatMapStrings bindReadOnly readOnlyPaths}
  ${lib.concatMapStrings bindReadWrite readWritePaths}

  PROFILE=$(mktemp "''${TMPDIR:-/tmp}/termcheck-sandbox.XXXXXX.sb")
  cleanup_profile() {
    rm -f "$PROFILE"
  }
  trap cleanup_profile EXIT

  printf '%s\n' "''${PROFILE_RULES[@]}" > "$PROFILE"

  export PATH=${lib.escapeShellArg sandboxPath}
  export REPO_ROOT
  export SSL_CERT_FILE=${lib.escapeShellArg "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"}
  export NIX_SSL_CERT_FILE=${lib.escapeShellArg "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"}
  export GIT_SSL_CAINFO=${lib.escapeShellArg "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"}

  exec /usr/bin/sandbox-exec -f "$PROFILE" ${lib.escapeShellArgs command}
''
