# .files

Personal dotfiles for **zsh**, **tmux**, **neovim**, and **opencode**, designed to install entirely under `$HOME` on glibc Linux and work unchanged inside Toolbx containers and on servers.

> Status: scaffolding. The design is in [PLAN.md](PLAN.md); agent guidance is in [AGENTS.md](AGENTS.md). The installer scripts are not implemented yet.

## Intended install

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/main/bootstrap.sh | bash
```

The bootstrap checks for missing system tools, prints the exact command for your distro, and never runs `sudo`. Dev tools are installed per-user with `mise` and `micromamba`.

## Components

- `core` — directories, PATH, shell hook
- `zsh` — micromamba zsh, oh-my-zsh, plugins, fzf, starship
- `tmux` — vague theme, keymaps, resurrect/continuum
- `nvim` — NvChad config with a vague base46 theme
- `opencode` — config and vague theme

## Secrets

`~/.config/opencode/service.json` contains local credentials and is ignored. Do not commit it.
