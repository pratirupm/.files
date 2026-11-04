# .files

Personal dotfiles for **zsh**, **tmux**, **neovim**, and **opencode**, installed
entirely under `$HOME` on glibc Linux. The same checkout works on a workstation,
inside a Toolbx container with a shared `$HOME`, and on a server over SSH.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/main/bootstrap.sh | bash
```

The bootstrap clones or fast-forwards `~/.files`, runs the preflight, and hands
off to `install.sh`. It never runs `sudo`; if a system tool is missing it prints
the exact command for the detected distribution and exits.

Pinned variant:

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/v1/bootstrap.sh -o /tmp/bootstrap.sh
less /tmp/bootstrap.sh
bash /tmp/bootstrap.sh
```

`git` and an HTTPS fetcher (`curl`, or `wget`/`python3`/`busybox` as a fallback) are the only entry requirements. Everything else is installed per-user with `mise` and `micromamba`.

## Everyday commands

```sh
dotfiles install       # apply links/templates and install missing components
dotfiles update        # git pull --ff-only, then apply changes; no version bumps
dotfiles upgrade       # maintainer: verify, upgrade tools, commit lockfiles, push
dotfiles uninstall     # remove managed paths and restore backups
dotfiles uninstall --purge
dotfiles doctor
dotfiles status
```

Every command accepts `--dry-run` (`-n`). `install`, `update`, and `uninstall`
accept `--yes` (`-y`); `install` and `update` accept `--only zsh,tmux` (required
components are included automatically). `uninstall --purge` requires `--yes` or
an interactive confirmation.

zsh wrappers are installed as well: `dotfiles-install`, `dotfiles-update`,
`dotfiles-upgrade`, `dotfiles-uninstall`, `dotfiles-doctor`, `dotfiles-status`.

## Components

- `core` — `~/.local/bin/dotfiles` and the guarded bash login hook
- `zsh` — micromamba zsh, oh-my-zsh, plugins, fzf, and a vague starship prompt
- `tmux` — vague colors, keymaps, resurrect/continuum
- `nvim` — vendored NvChad config with a vague base46 theme
- `opencode` — config, vague theme, `AGENTS.md`, the `planner`/`builder`
  manager agents, the `scout`/`mechanical`/`worker` subagents, the
  force-background plugin, and the Playwright/Svelte `bunx` MCP servers

`doctor` and `status` are safe to run on a new machine. `doctor` checks
prerequisites, symlinks, rendered files, component markers, and versions.

## Layout

```text
bootstrap.sh          URL entrypoint (POSIX sh)
install.sh            install dispatcher
update.sh             update dispatcher
uninstall.sh          uninstall dispatcher
bin/dotfiles          single implementation of every command
lib/                  common, preflight, graph, component API
components/<name>/    component.conf, hooks.sh, and config files
mise.toml / mise.lock pinned tool versions (x86_64 and aarch64)
tests/run.sh          hermetic install/update/uninstall/upgrade tests
```

## Safety and preservation

- Nothing outside `$HOME` is written; system package commands are only printed.
- Existing unmanaged paths are backed up under
  `~/.local/state/dotfiles/backups/<run-id>/` before being replaced.
- `dotfiles uninstall` removes only manifest-recorded links/templates, restores
  backups, and leaves modified files alone with a warning.
- `--purge` additionally removes recovery state, repo-installed tools, and
  `~/.files` last.
- Even with `--purge`, these are preserved: `~/.local/share/opencode`,
  `~/.config/opencode/service.json`, `~/.config/opencode/skills`,
  `~/.local/state/zsh/history`, `~/.tmux/resurrect`,
  `~/.local/share/nvim/projects.json`, and nvim shada/history.
- `service.json` is never committed; `**/service.json` and `**/skills/` are
  ignored.

## Verification

```sh
shellcheck bootstrap.sh install.sh update.sh uninstall.sh bin/dotfiles lib/*.sh components/*/hooks.sh
bash -n bootstrap.sh install.sh update.sh uninstall.sh bin/dotfiles lib/*.sh components/*/hooks.sh
stylua --check components/nvim
tests/run.sh
```

CI runs the lint checks, JSON validation, and gitleaks. Container checks run
with a throwaway `HOME`:

```sh
podman run --rm -e HOME=/tmp/testhome -v "$PWD:/src:ro" fedora:44 bash /src/bin/dotfiles install --dry-run
```

## Secrets

`~/.config/opencode/service.json` contains local credentials and is ignored.
Do not commit it. The opencode theme and config are committed; auth, sessions,
and skills are not.
