# `.files` — personal dotfiles plan

## Goal

One public repository that provisions four configs — **zsh**, **tmux**, **neovim**, **opencode** — on any glibc Linux machine, entirely under `$HOME`, with `install`, `update`, `uninstall`, and `doctor` commands.

It must work the same on a workstation, inside a Toolbx container (shared `$HOME`), and on a server over SSH, without installing system packages from the scripts.

## Status

All phases are implemented for this repository: preflight, lifecycle commands,
components, themes, tests, CI, the host migration, and archiving the old
`pratirupm/nvim` repository. Other machines only need `dotfiles install`.

## Constraints

- Everything owned by the user lives under `$HOME`.
- The installer never runs `sudo`.
- Missing system prerequisites are detected and reported with the exact command for the detected distro.
- Supported: Linux `x86_64` / `aarch64`, glibc `>= 2.34` for Neovim 0.12.6.
- musl/Alpine is detected and rejected with an explanation, not a half-install.
- The repository is public, so no secrets are committed.
- Toolbx shares `$HOME`; configs and binaries must be usable there without copying.

## Decisions

| Area | Decision |
| --- | --- |
| Package manager | `mise` for dev tools and runtimes |
| zsh source | `micromamba` environment under `~/.local/share/dotfiles/zsh` |
| zsh framework | oh-my-zsh, cloned under `~/.local/share/oh-my-zsh` |
| nvim | vendored copy of `pratirupm/nvim` |
| tmux | static `tmux-builds` binary via mise, TPM plugins |
| opencode | official OpenCode V2 installer, theme + config |
| Theme | vague, ported into base46 for NvChad |
| Login shell | guarded `exec ~/.local/bin/zsh -l` from bash; no `chsh` |
| Repo | public `pratirupm/.files`, cloned at `~/.files` |

Linuxbrew is ruled out. Nix/NixOS is not used: `/nix` is outside `$HOME`, `nix-portable` adds proot, and neither improves Toolbx pickup.

## Repository layout

```text
.files/
  bootstrap.sh            # URL entrypoint: preflight, clone, exec install.sh
  install.sh
  update.sh
  uninstall.sh
  bin/dotfiles            # install | update | upgrade | uninstall | doctor | status
  lib/
    common.sh             # logging, locking, run/dry-run
    preflight.sh          # distro, arch, libc, dependency report
    component-api.sh      # link, template, manifest, backup, clone helpers
    graph.sh              # discovery, dependency sort
  components/
    core/
    zsh/
    tmux/
    nvim/
    opencode/
  mise.toml
  mise.lock
  PLAN.md
  AGENTS.md
  README.md
```

Component directories hold the actual config files, hooks, and `component.conf`; this plan is implemented by the scripts and components in the repository.

## Bootstrap

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/main/bootstrap.sh | bash
```

Pinned variant:

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/v1/bootstrap.sh -o /tmp/bootstrap.sh
less /tmp/bootstrap.sh
bash /tmp/bootstrap.sh
```

`bootstrap.sh` is POSIX `sh` and:

1. Detects distro family, package manager, architecture, libc, glibc.
2. Checks the fetcher (`curl`, or `wget`/`python3`/`busybox wget` as fallbacks).
3. Runs the shared preflight and stops before changing anything if a required tool is missing.
4. Clones or fast-forwards `https://github.com/pratirupm/.files.git` into `~/.files`.
5. Execs `~/.files/install.sh "$@"`.

The one unavoidable entry requirement is an HTTPS fetcher. If none exists, the script prints the install command for the detected package manager and exits.

After the first run, use `dotfiles update`, `dotfiles upgrade`, `dotfiles uninstall`, `dotfiles doctor`, or `dotfiles status`. The URL is only needed on a new machine or after a full wipe.

## Preflight

Required system tools and why:

| Tool | Reason |
| --- | --- |
| `git` | lazy.nvim, oh-my-zsh, tpm |
| `curl` (or `wget`/`python3`/`busybox`) | mise, micromamba, release downloads; the OpenCode installer requires `curl` specifically |
| `tar`, `gzip`, `xz`, `bzip2` | release archives |
| `unzip` | Mason `.zip` packages |
| `find` | runtime and plugin lookups |
| `gcc`, `make` | nvim-treesitter parser builds |
| CA bundle | HTTPS verification |

`node` and `go` are installed by mise and are not system requirements.

The report is per component, for example:

```text
Detected: Fedora Linux 44 (fedora), x86_64, glibc 2.43

Missing system tools:
  gcc     nvim: compile treesitter parsers
  make    nvim: build treesitter parsers
  unzip   nvim: extract Mason zip packages

Install with:
  sudo dnf install gcc make unzip
```

Package mapping is per family: `dnf`, `apt` (`build-essential`), `pacman` (`base-devel`), `zypper`, `apk` (`build-base`). NixOS is unsupported: the plan does not write to `/nix`.

Additional checks:

- glibc `< 2.34` → stop with the Neovim compatibility explanation.
- musl → stop before downloading anything.
- noexec `$HOME` → explain why binaries cannot run.
- less than ~2 GB free in `$HOME` → warn.
- existing unmanaged config path → require `--yes` and create a backup.

## Package management

`mise` (`~/.local/share/mise`) supplies:

- `neovim` 0.12.6
- `tmux` 3.7c (static `aqua:tmux/tmux-builds`)
- `fzf`, `fd`, `ripgrep`, `eza`, `starship`, `zoxide`
- `go`, `node`, `bun` for Mason packages and the `bunx` MCP commands
- `lazygit`, `stylua`, `shellcheck`, `shfmt`

`~/.local/share/mise/shims` must be on `PATH`; `mise reshim` is run after installs.

`micromamba` supplies zsh only, in `~/.local/share/dotfiles/zsh`. The raw micromamba binary is downloaded directly (no tar needed), then:

```sh
micromamba create -p "$HOME/.local/share/dotfiles/zsh" -c conda-forge zsh
ln -s "$HOME/.local/share/dotfiles/zsh/bin/zsh" "$HOME/.local/bin/zsh"
```

## Component system

Each component is a directory with `component.conf` and optional `hooks.sh`.

`component.conf` (TEMPLATES entries use `source|target|mode`; the tmux component renders `tmux.conf` this way so `${HOME}` is expanded at install time):

```sh
NAME="nvim"
DESCRIPTION="Neovim editor and plugins"
REQUIRES=("core")
AFTER=("zsh")
SYSTEM_DEPS=("gcc|compile treesitter parsers" "make|build treesitter parsers")
LINKS=("$DOTFILES/nvim|$HOME/.config/nvim")
TEMPLATES=()
DATA_DIRS=("$HOME/.local/share/nvim/lazy" "$HOME/.local/share/nvim/mason" "$HOME/.local/share/nvim/base46" "$HOME/.cache/nvim")
```

Hooks:

- `component_install`
- `component_update`
- `component_uninstall`
- `component_doctor`
- optional `component_pre_install`, `component_post_install`

Core lifecycle:

1. Lock, detect OS, discover components, topologically sort.
2. Aggregate `SYSTEM_DEPS`, run preflight.
3. Install mise + micromamba.
4. `mise install` for all tools in `mise.toml`.
5. Create the zsh environment.
6. Per component: apply links/templates, run `install`, mark installed. The opencode component runs the official V2 installer and refreshes its Playwright Chromium.
7. `doctor`.

`update` runs the install path for components that are not marked installed, so adding `components/python/` later is picked up automatically.

Every created path is recorded in `~/.local/state/dotfiles/manifest.tsv`; replaced files are moved to timestamped backups. Uninstall removes only recorded links that still point at the component and restores backups in reverse order. `DATA_DIRS` that existed before install are recorded as pre-existing and left alone; data created by the component is removed. `--purge` removes the remaining declared data plus recovery state.

## Command surface

The URL is used once. Afterwards the `dotfiles` command and zsh wrappers handle everything:

| Command | Action |
| --- | --- |
| `dotfiles install` | Re-apply links, install missing components, run doctor; `--only` includes required dependencies |
| `dotfiles update` | `git pull --ff-only`, then apply new/changed components; no version bumps |
| `dotfiles upgrade` | Maintainer action: verify a clean, pushable checkout, then upgrade tools/plugins/Mason/themes, commit lockfile changes, and push |
| `dotfiles uninstall [--purge]` | Remove managed configs, generated data, commands, and restore backups; `--purge` also removes recovery state, repo-installed tools, and the checkout |
| `dotfiles doctor` | Preflight, symlink, version, and component health checks |
| `dotfiles status` | Current versions and component state |

`bin/dotfiles` is the single implementation. `components/core` links it to `~/.local/bin/dotfiles`, so it works in bash and zsh.

`components/zsh/dotfiles.zsh` is linked to `~/.config/zsh/dotfiles.zsh` and sourced from `.zshrc`. It defines thin wrappers:

```zsh
dotfiles-install()   { command dotfiles install "$@" }
dotfiles-update()    { command dotfiles update "$@" }
dotfiles-upgrade()   { command dotfiles upgrade "$@" }
dotfiles-uninstall() { command dotfiles uninstall "$@" }
dotfiles-doctor()    { command dotfiles doctor "$@" }
dotfiles-status()    { command dotfiles status "$@" }
```

Wrappers contain no logic; they only forward to `bin/dotfiles`. Every command supports `--dry-run`; install/update also support `--only LIST`, which always includes `REQUIRES`. Interactive confirmations read `/dev/tty`, because `curl | bash` leaves stdin attached to the pipe. `update` and `upgrade` are deliberately separate so pulling config changes never silently bumps tool versions. `update` re-runs the base46 cache rebuild after applying Neovim changes, and `upgrade` does it again after updating Neovim.

### Upgrade and publish

`dotfiles upgrade` is the maintainer path. It refuses to start unless the working tree is clean and `HEAD` is on a branch with an upstream. It verifies that the checkout is clean and has an upstream, verifies `git push --dry-run` to that upstream succeeds, then pulls with `--ff-only` and runs the upgrades from the updated checkout.

If tracked files changed (typically `mise.lock` and `nvim/lazy-lock.json`) it stages only tracked modifications with `git add -u`, commits `chore: upgrade tools YYYY-MM-DD`, and pushes. If the push fails, the command exits non-zero and leaves the commit local for inspection. It never force-pushes and never stages untracked files.

If nothing tracked changed, it reports that and exits 0 without a commit. Consumers who only need config changes run `dotfiles update`, which pulls and applies but never pushes.

### Uninstall and purge

`dotfiles uninstall` reverses the installation:

- removes managed symlinks and rendered files only if they still point at the repo or match the recorded checksum;
- restores the newest backups first;
- removes marked blocks from `.bash_profile` and `.bashrc`;
- removes `~/.local/bin/dotfiles` and the `dotfiles-*` zsh wrappers;
- removes component-owned data recorded as newly created (`DATA_DIRS`): the micromamba zsh env, oh-my-zsh, tmux plugins, nvim lazy/Mason/base46, and generated caches; pre-existing data is preserved;
- removes directories recorded as created by the installer, but only when empty.

It keeps recovery state in `~/.local/state/dotfiles` and the `~/.files` checkout so a failed uninstall can be inspected or re-run.

`dotfiles uninstall --purge` additionally removes:

- `~/.local/state/dotfiles` (manifest, logs, backups) after a successful restore;
- tools installed by the repo (`mise uninstall` for recorded tools, micromamba and its env);
- the OpenCode binary under `~/.opencode/bin` when this repo ran the official installer;
- `~/.files` last, after all scripts have loaded.

Always preserved even with `--purge`:

- `~/.local/share/opencode` (auth and sessions)
- `~/.config/opencode/service.json`
- `~/.config/opencode/skills`
- `~/.local/state/zsh/history`
- `~/.tmux/resurrect`
- `~/.local/share/nvim/projects.json`
- nvim shada and command history

`--purge` requires `--yes` or an interactive confirmation. Every removal is resolved under `$HOME`, must be present in the manifest, and is skipped with a warning if the path was replaced or edited by the user. `--dry-run` lists the complete removal set without changing anything.

## zsh

- `ZDOTDIR=~/.config/zsh`, linked from `zsh/zshenv` and `zsh/zshrc`.
- `fpath` is prepended with the micromamba environment's `share/zsh/site-functions` and `share/zsh/*/functions`, because the built-in `fpath[1]` points at `/usr/local/share/zsh/site-functions`.
- oh-my-zsh at `~/.local/share/oh-my-zsh`; plugins: `git`, `golang`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, conditional `zsh-eza`.
- `ZSH_THEME` is empty when starship exists, `robbyrussell` otherwise.
- oh-my-zsh auto-update is disabled; `dotfiles upgrade` pulls it.
- `HISTFILE=~/.local/state/zsh/history`.
- `dotfiles.zsh` is linked to `~/.config/zsh/dotfiles.zsh`, sourced after oh-my-zsh, and defines the `dotfiles-*` wrappers.
- `mise activate zsh` and starship init are guarded by `command -v`.
- `MISE_GLOBAL_CONFIG_FILE=$HOME/.files/mise.toml` makes the repository the global version source, so mise shims (`starship`, `tmux`, `nvim`) work from any directory.
- `~/.opencode/bin` is placed ahead of the mise shims so the official OpenCode binary wins.
- `fzf` integration: `source <(fzf --zsh)`; this provides `C-r` history, `C-t` files, `M-c` cd.
- `FZF_DEFAULT_OPTS` uses the vague-fzf palette.
- `starship.toml` defines a vague palette and module styles; it is linked to `~/.config/starship.toml`.
- Login: a marked block in `~/.bash_profile` and `~/.bashrc` runs only for interactive shells, tests the working binary, then `exec ~/.local/bin/zsh -l`. `chsh` and `/etc/shells` are not touched; non-interactive `bash -lc` is left alone.
- tmux `default-shell` points at the same zsh, so tmux starts zsh even when bash is the login shell.

## tmux

- `vague-tmux/vague.conf` is vendored as `tmux/vague.conf` and sourced first.
- Status stays at the top, as in the current setup.
- Prefix `C-a`, with `bind C-a send-prefix`.
- `|` / `-` split in the current directory; `h/j/k/l` select panes; `H/J/K/L` resize.
- `c` opens a window in the current directory; `Tab` last window; `r` reload.
- Mouse on; vi copy mode; `set-clipboard on` for OSC 52; `allow-passthrough`.
- `history-limit 50000`, `escape-time 10`, `focus-events on`, base index 1.
- Plugins: tpm, resurrect, continuum, prefix-highlight. Optional `tmux-fzf`.
- `resurrect` saves every 15 minutes and restores on start.

## neovim

- The current `~/.config/nvim` is copied into `nvim/` without `.git`; `~/.config/nvim` becomes a symlink to it.
- The old `pratirupm/nvim` repository is archived after migration so there is one source of truth.
- Mason remains fully enabled; no `--no-mason` mode.
- Install runs `nvim --headless "+Lazy! restore" +qa`, then `MasonToolsInstallSync`, then `base46.load_all_highlights()`.
- NvChad theme is a base46 port of vague in `lua/themes/vague.lua`; `theme = "vague"` in `lua/chadrc.lua`.
- `vague.nvim` is **not** loaded directly: base46 caches load after plugins and would overwrite it, or `colorscheme vague` would clear NvChad's `St*`/`Tb*` groups.
- `TabOn`/`TabOff` and `BufOn`/`BufOff` are undefined in base46; link them to `TbTabOn`/`TbTabOff`/`TbBufOn`/`TbBufOff` after theme load.
- `lazy-lock.json` is committed; `update` runs restore and rebuilds base46, not `:Lazy sync`.

## opencode

- Installed by the official OpenCode V2 installer (`https://opencode.ai/v2/install`) into `~/.opencode/bin`, always with `--no-modify-path`; the repo owns `PATH`.
- `opencode.json` is linked, with `"theme": "vague"` and `"update": "auto"`; OpenCode updates itself and `dotfiles upgrade` does not manage it.
- The built-in `build` and `plan` agents are left enabled; there are no custom agents or global `AGENTS.md`.
- `vague-opencode/vague.json` is vendored as `opencode/themes/vague.json` and linked to `~/.config/opencode/themes/vague.json`.
- The absolute bun path in the Playwright MCP command is replaced with `bunx -y @playwright/mcp@latest`; `bun` is installed by mise.
- Install resolves the Playwright version required by the current `@playwright/mcp` release and runs `bunx -y playwright@<version> install chromium`. There is no prompt or browser toggle; the MCP always has its matching Chromium.
- `service.json` is never committed; it contains a password. `skills/` is excluded (5.5 MB).

## Vague theme

Available ports used:

- Neovim: base46 port from `vague.nvim`'s palette.
- tmux: `vague-tmux`.
- fzf: `vague-fzf` color flags.
- opencode: `vague-opencode`.
- starship: vague palette in `components/zsh/starship.toml`.
- Optional: `vague-lazygit`, `vague-bat`, and a terminal port (ghostty/kitty/alacritty/wezterm) once the terminal is known.

## Testing

- `shellcheck` all scripts; `bash -n`; `stylua --check components/nvim`.
- `podman run --rm` with `HOME` in a container-local dir or tmpfs, never the host home.
- Cases:
  1. stripped Fedora: preflight reports missing git/gcc/make and exits 2;
  2. install prerequisites, then full install;
  3. update with a new fake component;
  4. upgrade with a writable bare remote commits and pushes; with a read-only remote it fails before upgrading;
  5. uninstall removes managed links, commands, shell blocks, plugin data, and caches; backups restore; no dangling symlinks remain;
  6. purge removes state and the checkout while preserving user data;
  7. Ubuntu, Debian, Arch containers for package-manager mapping;
  8. Alpine for the musl message;
  9. Toolbx shared-home pickup;
  10. same test home in a second distro container.
- CI: `shellcheck`, `gitleaks`, `stylua`, `bash -n`.

## Implementation phases

1. Scaffold repo, docs, gitignore, CI.
2. `lib/common.sh`, `lib/preflight.sh`, `lib/component-api.sh`, `lib/graph.sh`.
3. `core`, `zsh` components; bootstrap; `dotfiles` dispatcher, `dotfiles-*` zsh wrappers, install/update/upgrade/uninstall/doctor.
4. `tmux`, `nvim`, `opencode` components.
5. Container matrix and Toolbx tests.
6. Migrate the host: link configs, verify, then push.
7. Archive `pratirupm/nvim`.

## Open items

- Terminal emulator theme: ghostty, kitty, alacritty, or wezterm.
- Whether `lazygit` and `bat` become components or stay optional extras.
- Whether `vague.nvim`'s extra plugin groups (blink, snacks, fzf-lua, neotree) need manual ports; the current plugin set does not use them.
