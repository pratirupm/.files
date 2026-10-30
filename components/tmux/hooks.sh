# shellcheck shell=bash
# tmux component hooks.

TMUX_PLUGINS="$HOME/.tmux/plugins"

_tmux_plugins() {
  clone_repo https://github.com/tmux-plugins/tpm.git "$TMUX_PLUGINS/tpm"
  clone_repo https://github.com/tmux-plugins/tmux-resurrect.git "$TMUX_PLUGINS/tmux-resurrect"
  clone_repo https://github.com/tmux-plugins/tmux-continuum.git "$TMUX_PLUGINS/tmux-continuum"
  clone_repo https://github.com/tmux-plugins/tmux-prefix-highlight.git "$TMUX_PLUGINS/tmux-prefix-highlight"
}

component_install() {
  _tmux_plugins
}

component_update() {
  # plugin pulls belong to upgrade, not update
  _tmux_plugins
}

component_uninstall() {
  # Plugin data is listed in DATA_DIRS and removed by the manifest.
  :
}

component_doctor() {
  local failures=0 plugin
  if ! command -v tmux >/dev/null 2>&1; then
    error "tmux is not on PATH"
    failures=$((failures + 1))
  fi
  for plugin in tpm tmux-resurrect tmux-continuum tmux-prefix-highlight; do
    if [[ ! -d "$TMUX_PLUGINS/$plugin" ]]; then
      error "tmux plugin is missing: $plugin"
      failures=$((failures + 1))
    fi
  done
  return "$failures"
}
