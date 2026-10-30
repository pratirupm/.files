# .files

Personal dotfiles for **zsh**, **tmux**, **neovim**, and **opencode**, designed to install entirely under `$HOME` on glibc Linux and work unchanged inside Toolbx containers and on servers.

> Status: scaffolding. The design is in [PLAN.md](PLAN.md); agent guidance is in [AGENTS.md](AGENTS.md). The installer scripts are not implemented yet.

## Intended install

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/main/bootstrap.sh | bash
```

The bootstrap checks for missing system tools, prints the exact command for your distro, and never runs `sudo`. Dev tools are installed per-user with `mise` and `micromamba`.

## Everyday commands

After the first install, no URL is needed:

| Command | Action |
| --- | --- |
| `dotfiles update` | Pull config changes and apply them; no version bumps |
| `dotfiles upgrade` | Maintainer: verify push access, upgrade tools/plugins/Mason/themes, commit lockfiles, push |
| `dotfiles install` | Re-apply links and install missing components |
| `dotfiles uninstall [--purge]` | Remove managed configs and generated data; restore backups; `--purge` also removes state, tools, and the checkout |
| `dotfiles doctor` | Check prerequisites, links, and component health |
| `dotfiles status` | Show current versions and state |

zsh wrappers are installed as well: `dotfiles-update`, `dotfiles-upgrade`, `dotfiles-install`, `dotfiles-uninstall`, `dotfiles-doctor`, `dotfiles-status`.

## Components

- `core` — directories, PATH, shell hook
- `zsh` — micromamba zsh, oh-my-zsh, plugins, fzf, starship
- `tmux` — vague theme, keymaps, resurrect/continuum
- `nvim` — NvChad config with a vague base46 theme
- `opencode` — config and vague theme

## Secrets

`~/.config/opencode/service.json` contains local credentials and is ignored. Do not commit it.
