
# TermCheck

Formal access rules for shells and programs

This utility combines Nix with BubbleWrap to provide configurable, declarative command wrappers with predefined rules for network access, file/directory access, and command usage.

## Description

The user of this flake should be able to state in a policy.nix file the following options:

- Which files are accessible
- Which programs are allowed
- (would be nice) which commands from the host's PATH will be available, such as IDEs, text editors, AI assistants, etc.
    - This would also require users to declare some home dirs as read+write so the IDEs can access settings and stuff. Feels hacky but I can't think of any better solution. Maybe add a bunch of common home dirs where this kind of stuff is stored behind some "default" flag?

## Features

- [ ] Restrict internet access
- [ ] Restrict command usage
- [ ] Correctly execute desired command
    - [ ] Get graphical applications working

## Stretch goals

- [ ] Restrict patterns of commands (i.e. disallow `git rebase` but allow other git commands)
- [ ] MacOS support? Will need to use `sandbox-exec`?

