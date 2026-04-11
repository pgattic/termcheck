{ lib, pkgs, policy, ... }: let

  defaultPkgs = [ "coreutils" "bash" "python3" ];
  configuredPkgs = with policy.packages; allowed ++ (lib.optionals allowDefaults defaultPkgs);

  # Minimal PATH containing only allowed commands
  allowedPkgs = map (name: pkgs.${name}) configuredPkgs;
  sandboxPath = pkgs.lib.makeBinPath allowedPkgs;

  netFlag = if policy.network.enable then "" else "--unshare-net";
in
pkgs.writeShellScriptBin "launch-sandbox" ''
  # Resolve repo root at runtime
  REPO_ROOT=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$REPO_ROOT" ]; then
    echo "error: not inside a git repository" >&2
    exit 1
  fi

  # Resolve a policy path against the repo root
  resolve_path() {
    local p="$1"
    case "$p" in
      /*)  echo "$p" ;;           # already absolute, pass through
      ./*) echo "$REPO_ROOT/''${p#./}" ;;  # repo-relative
      *)   echo "$REPO_ROOT/$p" ;;         # bare name, treat as repo-relative
    esac
  }

  # Build bind mount args dynamically from policy
  MOUNTS=()
  ${pkgs.lib.concatMapStrings (p: ''
    MOUNTS+=(--ro-bind "$(resolve_path '${p}')" "$(resolve_path '${p}')")
  '') policy.filesystem.readOnly}
  ${pkgs.lib.concatMapStrings (p: ''
    MOUNTS+=(--bind "$(resolve_path '${p}')" "$(resolve_path '${p}')")
  '') policy.filesystem.readWrite}

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
    --setenv PATH ${sandboxPath} \
    --setenv REPO_ROOT "$REPO_ROOT" \
    -- ${lib.escapeShellArgs policy.command}
''

