# shellcheck shell=bash
# Neovim component hooks. Mason stays fully enabled.

NVIM_DATA="$HOME/.local/share/nvim"

component_install() {
  if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim is not on PATH; plugins and Mason were not installed"
    return 0
  fi

  info "restore Neovim plugins from lazy-lock.json"
  run nvim --headless "+Lazy! restore" +qa
  info "install Mason tools"
  run nvim --headless "+MasonToolsInstallSync" +qa
  info "build base46 caches"
  run nvim --headless "+lua require('base46').load_all_highlights()" +qa
}

component_update() {
  if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim is not on PATH; skipped plugin restore"
    return 0
  fi
  # update restores the committed lockfile; upgrade owns `Lazy! sync`.
  run nvim --headless "+Lazy! restore" +qa
  run nvim --headless "+lua require('base46').load_all_highlights()" +qa
}

component_uninstall() {
  :
}

component_doctor() {
  local failures=0
  if ! command -v nvim >/dev/null 2>&1; then
    error "nvim is not on PATH"
    failures=$((failures + 1))
  fi
  if [[ ! -d "$NVIM_DATA/lazy" ]]; then
    error "lazy.nvim data directory is missing: $NVIM_DATA/lazy"
    failures=$((failures + 1))
  fi
  if [[ ! -f "$DOTFILES/components/nvim/lazy-lock.json" ]]; then
    error "lazy-lock.json is missing from the repository"
    failures=$((failures + 1))
  fi
  if [[ ! -f "$DOTFILES/components/nvim/lua/themes/vague.lua" ]]; then
    error "the vague base46 theme is missing"
    failures=$((failures + 1))
  fi
  if [[ ! -d "$NVIM_DATA/base46" ]]; then
    error "base46 cache is missing; run dotfiles install"
    failures=$((failures + 1))
  fi
  return "$failures"
}
