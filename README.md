# TermCheck

Formal access rules for shells and programs

TermCheck combines Nix with BubbleWrap to generate declarative command wrappers with predefined rules for network access, filesystem access, and the command environment exposed through `PATH`.

## Current status

This is an early Linux-only prototype. It can:

- run a configured command inside a BubbleWrap sandbox
- hide all filesystem paths except declared read-only and read-write mounts
- disable networking, or preserve host networking when `network.enable = true`
- expose only configured nixpkgs packages on `PATH`
- validate policy shape at Nix evaluation time

It does not yet provide strong executable allowlisting. The sandbox currently binds `/nix` read-only so allowed packages can run with their full runtime closures. Because of that, a process may still execute another binary by absolute `/nix/store/...` path if it can discover that path. Treat `packages.allowed` as a curated `PATH`, not as a complete command firewall.

## Usage

Run the example policy:

```sh
nix run .
```

Build the wrapper:

```sh
nix build .
./result/bin/launch-sandbox
```

Use the module from another flake:

```nix
inputs.termcheck.url = "github:your-org/termcheck";

outputs = { self, nixpkgs, termcheck, ... }: {
  packages.x86_64-linux.my-sandbox =
    termcheck.lib.mkSandbox {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      name = "my-sandbox";
      policy = import ./policy.nix;
    };
};
```

## Policy

See `example-policy.nix` for the full example.

```nix
{
  filesystem = {
    readOnly = [ "./docs" "~/notes" "/etc/ssl/certs" ];
    readWrite = [ "." "~/.cache/my-tool" ];
  };

  network = {
    enable = false;
    allowedHosts = [];
  };

  packages = {
    allowDefaults = true;
    allowed = [ "git" "nodejs" ];
  };

  command = [ "bash" ];
}
```

Relative filesystem paths are resolved against the current Git repository root when the wrapper starts. `~` and `~/...` paths are resolved against the invoking user's `HOME`. Absolute paths are mounted at the same absolute path inside the sandbox.

`network.allowedHosts` is reserved for a future proxy/firewall integration. It must be `[]` for now.

## Development

```sh
nix flake check
```

The current check validates that the generated launcher is syntactically valid shell.

## Roadmap

- [x] Restrict internet access with network namespace isolation
- [x] Execute the configured command
- [x] Validate malformed policies early
- [x] Expose a reusable flake helper
- [ ] Mount only the Nix store closure needed by the allowed packages
- [ ] Add stronger executable allowlisting
- [ ] Restrict command patterns, such as disallowing `git rebase` while allowing other Git commands
- [ ] Add graphical application support
- [ ] Add host allowlisting through a proxy or firewall integration
- [ ] Investigate macOS support with `sandbox-exec` or a replacement
