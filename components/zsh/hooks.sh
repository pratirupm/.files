# shellcheck shell=bash
# zsh component hooks.

ZSH_ENV="$HOME/.local/share/dotfiles/zsh"
OH_MY_ZSH="$HOME/.local/share/oh-my-zsh"

_zsh_plugins() {
  clone_repo https://github.com/zsh-users/zsh-autosuggestions.git \
    "$OH_MY_ZSH/custom/plugins/zsh-autosuggestions"
  clone_repo https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$OH_MY_ZSH/custom/plugins/zsh-syntax-highlighting"
  clone_repo https://github.com/zsh-contrib/zsh-eza.git \
    "$OH_MY_ZSH/custom/plugins/zsh-eza"
}

component_install() {
  if ! command -v micromamba >/dev/null 2>&1; then
    warn "micromamba is not available; zsh environment was not created"
    return 0
  fi

  if [[ ! -x "$ZSH_ENV/bin/zsh" ]]; then
    info "create micromamba zsh environment"
    run micromamba create -y -p "$ZSH_ENV" -c conda-forge zsh
  fi

  if [[ -x "$ZSH_ENV/bin/zsh" ]]; then
    link_path "$ZSH_ENV/bin/zsh" "$HOME/.local/bin/zsh"
  fi

  if [[ ! -d "$OH_MY_ZSH/.git" ]]; then
    clone_repo https://github.com/ohmyzsh/ohmyzsh.git "$OH_MY_ZSH"
  fi
  _zsh_plugins
}

component_update() {
  # update never pulls plugins; upgrade owns that. It still repairs a missing
  # environment or clone after a partial first install.
  component_install
}

component_uninstall() {
  if [[ -L "$HOME/.local/bin/zsh" && $(readlink -- "$HOME/.local/bin/zsh") == "$ZSH_ENV/bin/zsh" ]]; then
    run rm -f -- "$HOME/.local/bin/zsh"
  fi
}

component_doctor() {
  local failures=0
  if ! command -v zsh >/dev/null 2>&1; then
    error "zsh is not on PATH"
    failures=$((failures + 1))
  fi
  if [[ ! -x "$ZSH_ENV/bin/zsh" ]]; then
    error "micromamba zsh environment is missing: $ZSH_ENV"
    failures=$((failures + 1))
  fi
  if [[ ! -r "$OH_MY_ZSH/oh-my-zsh.sh" ]]; then
    error "oh-my-zsh is missing: $OH_MY_ZSH"
    failures=$((failures + 1))
  fi
  local plugin
  for plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-eza; do
    if [[ ! -d "$OH_MY_ZSH/custom/plugins/$plugin" ]]; then
      error "zsh plugin is missing: $plugin"
      failures=$((failures + 1))
    fi
  done
  return "$failures"
}
