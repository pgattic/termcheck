{
  # Filesystem allowances
  filesystem = {
    readOnly = [
      "/etc/resolv.conf"     # only if network is allowed
      "/etc/ssl/certs"
      "./yeet"
    ];
    readWrite = [
      "." # the project the IDE works on
      "~/.codex"
    ];
    # everything else is invisible to the sandbox
  };

  # Network allowances
  network = {
    enable = false;
    # Host allowlisting is reserved for a future proxy/firewall integration.
    # For now, use [] with enable = true for unrestricted host networking.
    allowedHosts = [];
  };

  # The sandbox's PATH will contain only these
  packages = {
    # Add some packages that most LLMs expect to be on a system. Still does not give them access to the internet!
    allowDefaults = true;
    allowed = [
      "git"
      "nodejs"
      "neovim"
      "xeyes"
      "codex"
    ];
  };

  # Command to spawn in the sandbox (can be a shell like `bash`)
  command = [ "bash" ];
}
