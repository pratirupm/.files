# AGENTS.md

Personal dotfiles for **zsh, tmux, neovim, opencode** on glibc Linux, installed entirely under `$HOME`. Public repo: `pratirupm/.files`, checked out at `~/.files`. `PLAN.md` is the design document; this file is the working guide.

## Status

Scaffolding. Only `PLAN.md`, `AGENTS.md`, `README.md`, and `.gitignore` exist. The scripts and components described below are the target.

## Commands

```sh
./bootstrap.sh                 # clone/update then install
./install.sh [--yes] [--dry-run] [--only zsh,tmux,nvim,opencode]
./update.sh                    # pull, mise upgrade, component updates
./uninstall.sh [--purge]
bin/dotfiles doctor
bin/dotfiles status
```

Once published:

```sh
curl -fsSL https://raw.githubusercontent.com/pratirupm/.files/main/bootstrap.sh | bash
```

## Layout

```text
bootstrap.sh        POSIX sh; preflight -> clone -> exec install.sh
install.sh          bash; lifecycle dispatcher
update.sh           bash
uninstall.sh        bash
bin/dotfiles        bash; install|update|uninstall|doctor|status
lib/                common, preflight, component-api, graph
components/<name>/  component.conf + hooks.sh + config files
mise.toml           single source of truth for tool versions
mise.lock           committed
```

Initial components: `core`, `zsh`, `tmux`, `nvim`, `opencode`. Do not add `python/`, `rust/`, or `go/` placeholders; language support lives in `mise.toml` plus the nvim config unless it has standalone config files.

## Non-negotiables

- Never run `sudo`, `dnf`, `apt`, `pacman`, `zypper`, or `rpm-ostree` from the scripts.
- Missing system tools are reported by `lib/preflight.sh` with a distro-specific install command; the user installs them.
- Everything installed by the repo stays under `$HOME`; no writes to `/usr`, `/etc`, or `/nix`.
- No secrets in git. `~/.config/opencode/service.json` contains a password and must stay ignored. Never add `skills/` (5.5 MB).
- `bootstrap.sh` stays POSIX `sh`; `install.sh`, `update.sh`, and components use `bash`.
- `mise` and `micromamba` only; no Linuxbrew, no Nix.
- The repo is public: run `gitleaks` before pushing.

## Component contract

`component.conf` declares `NAME`, `DESCRIPTION`, `REQUIRES`, `AFTER`, `SYSTEM_DEPS` (`command|reason`), `LINKS` (`source|target`), `TEMPLATES` (`source|target|mode`), `DATA_DIRS`.

`hooks.sh` may define `component_install`, `component_update`, `component_uninstall`, `component_doctor`, `component_pre_install`, `component_post_install`. Use the helpers in `lib/component-api.sh`; do not call `ln`, `rm`, or `mv` on user configs directly.

`update` must run the install path for components without an installed marker, so a newly added component is picked up. State lives in `~/.local/state/dotfiles/` (manifest, backups, logs, component markers). Never edit that state by hand.

## Gotchas

- **mise PATH:** `mise install` does not expose tools. Add `~/.local/share/mise/shims` to `PATH` and run `mise reshim`; do not rely on `mise activate` for non-interactive use.
- **zsh:** micromamba env at `~/.local/share/dotfiles/zsh`, symlink `~/.local/bin/zsh`. Conda's `fpath[1]` points at `/usr/local/share/zsh/site-functions`; prepend the env's `share/zsh/site-functions` and `share/zsh/*/functions` in `.zshenv`. Do not use `chsh` or edit `/etc/shells`; the login hook tests that zsh actually runs before `exec`.
- **Toolbx:** `$HOME` is shared, so configs and binaries appear automatically. Keep them glibc-compatible and do not assume Fedora.
- **Neovim theme:** NvChad uses base46 bytecode caches loaded after plugins. `vague.nvim` must not be loaded directly; use the base46 port in `lua/themes/vague.lua` and `theme = "vague"`. After changing the theme run `nvim --headless "+lua require('base46').load_all_highlights()" +qa`.
- **base46 group names:** `TabOn`/`TabOff` and `BufOn`/`BufOff` are undefined. Link them to `TbTabOn`/`TbTabOff`/`TbBufOn`/`TbBufOff` and reapply on `User NvThemeReload`.
- **tmux:** `default-shell` points at `~/.local/bin/zsh`, so the tmux component requires `zsh`. Source the vendored `vague.conf` for colors, then apply keymaps. Keep `set-clipboard on` for OSC 52.
- **opencode:** replace absolute bun paths with `bunx -y`; commit a template, never `service.json`.
- **glibc:** Neovim 0.12.6 needs glibc >= 2.34. Detect musl and stop before downloading.

## Conventions

- 2-space Lua, `stylua`; `shellcheck` clean shell; `bash -n` every script.
- Marked blocks in `.bash_profile`/`.bashrc` for the zsh exec hook; never rewrite the whole file.
- Back up before linking; record every path in the manifest.
- Update `README.md` for user-facing keys and commands, `PLAN.md` for design changes, and this file for new traps.

## Verification

```sh
shellcheck bootstrap.sh install.sh update.sh uninstall.sh lib/*.sh components/*/hooks.sh
bash -n bootstrap.sh install.sh update.sh uninstall.sh
stylua --check nvim
gitleaks detect --source . --no-git
```

Container tests use a throwaway `HOME` and never the host home:

```sh
podman run --rm -e HOME=/tmp/testhome -v "$PWD:/src:ro" fedora:44 bash /src/install.sh --dry-run
```

Test stripped Fedora (preflight failure), Fedora with prerequisites (full install), Ubuntu/Debian/Arch package mapping, Alpine musl rejection, Toolbx shared-home pickup, update with a new component, uninstall/restore.
