{
  # Filesystem allowances
  filesystem = {
    readOnly = [
      "/etc/resolv.conf"     # only if network is allowed
      "/etc/ssl/certs"
      "$HOME/git/termcheck/yeet"
    ];
    readWrite = [
      "$HOME/git/termcheck" # the project the IDE works on
    ];
    # everything else is invisible to the sandbox
  };

  # Network allowances
  network = {
    enable = false;
    # if true, allowlist specific hosts via a proxy
    allowedHosts = [];
  };

  # The sandbox PATH will contain only these
  packages = [
    "git"
    "bash"
    "coreutils"
    "nodejs"
    "neovim"
  ];

  # Command to spawn in the sandbox (can be a shell like `bash`)
  command = [ "bash" ];
}

