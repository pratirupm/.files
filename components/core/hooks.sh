# shellcheck shell=bash
# Core component hooks.

DOTFILES_BLOCK_START="# >>> dotfiles >>>"
DOTFILES_BLOCK_END="# <<< dotfiles <<<"

_core_shell_hook() {
  cat <<'EOF'
# Managed by pratirupm/.files. Edits inside this block are overwritten.
if [ -x "$HOME/.local/bin/zsh" ]; then
  case $- in
    *i*)
      if "$HOME/.local/bin/zsh" -c 'exit 0' >/dev/null 2>&1; then
        exec "$HOME/.local/bin/zsh" -l
      fi
      ;;
  esac
fi
EOF
}

component_install() {
  local hook
  hook=$(_core_shell_hook)

  # Creating .bash_profile makes bash stop reading .profile, so keep the
  # standard profile working when we have to create the file.
  if [[ ! -f "$HOME/.bash_profile" ]] && ! $DRY_RUN; then
    printf '%s\n' '# Created by dotfiles; keeps ~/.profile working.' \
      "if [ -f \"\$HOME/.profile\" ]; then . \"\$HOME/.profile\"; fi" \
      >"$HOME/.bash_profile"
    manifest_add file "$HOME/.bash_profile" "" "$(file_checksum "$HOME/.bash_profile")"
  fi

  block_install "$HOME/.bash_profile" "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END" "$hook"
  block_install "$HOME/.bashrc" "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END" "$hook"
}

component_update() {
  component_install
}

component_uninstall() {
  block_remove "$HOME/.bash_profile" "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END"
  block_remove "$HOME/.bashrc" "$DOTFILES_BLOCK_START" "$DOTFILES_BLOCK_END"
}

component_doctor() {
  local failures=0 file
  for file in "$HOME/.bash_profile" "$HOME/.bashrc"; do
    if [[ -f $file ]] && grep -Fq "$DOTFILES_BLOCK_START" "$file"; then
      debug "shell hook present: $file"
    else
      error "shell hook missing from $file"
      failures=$((failures + 1))
    fi
  done
  return "$failures"
}
