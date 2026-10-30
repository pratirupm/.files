# shellcheck shell=bash
# Component links, rendered templates, manifest, backups, and data ownership.

manifest_add() {
  local kind=$1 path=$2 source=${3:-} checksum=${4:-}
  if $DRY_RUN; then
    debug "manifest: $kind $path"
    return 0
  fi

  # A data directory may be created by ensure_parent while cloning. Do not
  # downgrade its ownership to a plain directory, or uninstall would leave
  # plugin contents behind.
  if [[ $kind == dir ]] && { manifest_has data "$path" || manifest_has data-existing "$path"; }; then
    return 0
  fi

  state_init
  local tmp="$MANIFEST.tmp.$$"
  if [[ -f $MANIFEST ]]; then
    if [[ $kind == backup ]]; then
      cp -- "$MANIFEST" "$tmp"
    else
      awk -F '\t' -v OFS='\t' -v p="$path" '$2 != p || $1 == "backup"' "$MANIFEST" >"$tmp"
    fi
  else
    : >"$tmp"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$path" "$source" "$checksum" "$RUN_ID" >>"$tmp"
  mv -- "$tmp" "$MANIFEST"
}

manifest_has() {
  local kind=$1 path=$2
  [[ -f $MANIFEST ]] || return 1
  awk -F '\t' -v k="$kind" -v p="$path" '$1 == k && $2 == p {found=1} END {exit !found}' "$MANIFEST"
}

manifest_entry() {
  local path=$1
  [[ -f $MANIFEST ]] || return 1
  awk -F '\t' -v p="$path" '$2 == p && $1 != "backup" {line=$0} END {if (line) print line; exit(line ? 0 : 1)}' "$MANIFEST"
}

manifest_entries() {
  local kind=${1:-}
  [[ -f $MANIFEST ]] || return 0
  if [[ -n $kind ]]; then
    awk -F '\t' -v k="$kind" '$1 == k' "$MANIFEST"
  else
    cat -- "$MANIFEST"
  fi
}

is_managed_target() {
  local path=$1 entry kind source checksum
  entry=$(manifest_entry "$path" 2>/dev/null) || return 1
  IFS=$'\t' read -r kind _ source checksum _ <<<"$entry"

  case "$kind" in
    link)
      [[ -L $path && $(readlink -- "$path") == "$source" ]]
      ;;
    template)
      [[ -f $path && $(file_checksum "$path") == "$checksum" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

is_repo_symlink() {
  local path=$1 target
  [[ -L $path ]] || return 1
  target=$(readlink -- "$path")
  [[ $target == "$DOTFILES_DIR" || $target == "$DOTFILES_DIR/"* ]]
}

collect_unmanaged_targets() {
  local name spec source target
  local -A seen=()
  for name in "${ORDERED_COMPONENTS[@]}"; do
    component_load "$name"
    while IFS= read -r spec; do
      [[ -n $spec ]] || continue
      source=${spec%%|*}
      target=${spec#*|}
      [[ $target == "$spec" ]] && continue
      [[ -n ${seen[$target]:-} ]] && continue
      seen[$target]=1
      if [[ -e $target || -L $target ]]; then
        if is_managed_target "$target" || is_repo_symlink "$target"; then
          continue
        fi
        printf '%s\n' "$target"
      fi
    done <<<"${COMP_LINKS[$name]}"
    while IFS='|' read -r source target _; do
      [[ -n $target ]] || continue
      [[ -n ${seen[$target]:-} ]] && continue
      seen[$target]=1
      if [[ -e $target || -L $target ]]; then
        if is_managed_target "$target" || is_repo_symlink "$target"; then
          continue
        fi
        printf '%s\n' "$target"
      fi
    done <<<"${COMP_TEMPLATES[$name]}"
  done
}

backup_path() {
  local path=$1 rel dest
  assert_safe_remove "$path"
  rel=${path#"$HOME"/}
  [[ $rel != "$path" ]] || die "cannot back up \$HOME itself"
  dest="$BACKUPS_DIR/$RUN_ID/$rel"
  if [[ -e $dest ]]; then
    dest="$dest.$$"
  fi
  info "backing up $path -> $dest"
  run mkdir -p -- "$(dirname "$dest")"
  run mv -- "$path" "$dest"
  manifest_add backup "$path" "$dest" ""
}

ensure_parent() {
  local dir=$1
  local -a missing=()
  local d=$dir
  while [[ ! -d $d ]]; do
    missing+=("$d")
    [[ $d == "$HOME" || $d == "/" ]] && break
    d=$(dirname "$d")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  run mkdir -p -- "$dir"
  if ! $DRY_RUN; then
    local i
    for ((i = ${#missing[@]} - 1; i >= 0; i--)); do
      manifest_add dir "${missing[i]}" "" ""
    done
  fi
}

link_path() {
  local source=$1 target=$2
  [[ -e $source ]] || die "link source does not exist: $source"
  assert_under_home "$target"

  if [[ -L $target && $(readlink -- "$target") == "$source" ]]; then
    debug "already linked: $target"
    manifest_add link "$target" "$source" ""
    return 0
  fi

  if [[ -e $target || -L $target ]]; then
    if is_managed_target "$target"; then
      run rm -f -- "$target"
    else
      backup_path "$target"
    fi
  fi

  ensure_parent "$(dirname "$target")"
  info "link $target -> $source"
  run ln -s -- "$source" "$target"
  manifest_add link "$target" "$source" ""
}

render_template() {
  local source=$1 line var value
  local -a vars=(HOME DOTFILES XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME)
  while IFS= read -r line || [[ -n $line ]]; do
    for var in "${vars[@]}"; do
      value="${!var-}"
      line=${line//"\${$var}"/$value}
    done
    printf '%s\n' "$line"
  done <"$source"
}

template_path() {
  local source=$1 target=$2 mode=${3:-644}
  local tmp checksum previous previous_sum
  [[ -f $source ]] || die "template source does not exist: $source"
  assert_under_home "$target"

  tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-template.XXXXXX")
  render_template "$source" >"$tmp"
  checksum=$(file_checksum "$tmp")

  if [[ -e $target || -L $target ]]; then
    previous=$(manifest_entry "$target" 2>/dev/null || true)
    if [[ -n $previous ]]; then
      IFS=$'\t' read -r previous _ _ previous_sum _ <<<"$previous"
    fi
    if [[ ${previous:-} == template && ${previous_sum:-} == "$checksum" &&
      -f $target && $(file_checksum "$target") == "$checksum" ]]; then
      debug "template unchanged: $target"
    elif is_managed_target "$target"; then
      run rm -f -- "$target"
    else
      backup_path "$target"
    fi
  fi

  ensure_parent "$(dirname "$target")"
  info "template $target"
  run install -m "$mode" -- "$tmp" "$target"
  manifest_add template "$target" "$source" "$checksum"
  rm -f -- "$tmp"
}

apply_links() {
  local name=$1 spec source target
  while IFS= read -r spec; do
    [[ -n $spec ]] || continue
    source=${spec%%|*}
    target=${spec#*|}
    [[ $target == "$spec" ]] && die "invalid LINK entry for $name: $spec"
    link_path "$source" "$target"
  done <<<"${COMP_LINKS[$name]}"
}

apply_templates() {
  local name=$1 spec source target mode
  while IFS='|' read -r source target mode; do
    [[ -n $target ]] || continue
    template_path "$source" "$target" "${mode:-644}"
  done <<<"${COMP_TEMPLATES[$name]}"
}

record_data_dirs() {
  local name=$1 dir kind
  while IFS= read -r dir; do
    [[ -n $dir ]] || continue
    assert_under_home "$dir"
    ensure_parent "$(dirname "$dir")"
    manifest_has data "$dir" && continue
    manifest_has data-existing "$dir" && continue
    if [[ -e $dir ]]; then
      kind=data-existing
    else
      kind=data
    fi
    manifest_add "$kind" "$dir" "" ""
  done <<<"${COMP_DATA[$name]}"
}

component_mark_installed() {
  local name=$1
  $DRY_RUN && return 0
  mkdir -p "$INSTALLED_DIR"
  printf 'installed=%s\ncommit=%s\n' "$(timestamp)" "$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)" \
    >"$INSTALLED_DIR/$name"
}

component_is_installed() {
  [[ -f $INSTALLED_DIR/$1 ]]
}

component_mark_uninstalled() {
  local name=$1
  run rm -f -- "$INSTALLED_DIR/$name"
}

component_hooks_load() {
  local name=$1 hooks="$COMPONENTS_DIR/$1/hooks.sh"
  unset -f component_install component_update component_uninstall component_doctor
  unset -f component_pre_install component_post_install
  if [[ -f $hooks ]]; then
    # shellcheck source=/dev/null
    source "$hooks"
  fi
}

component_hook() {
  local hook=$1
  if declare -F "$hook" >/dev/null 2>&1; then
    "$hook"
  fi
}

component_install_one() {
  local name=$1
  component_load "$name"
  component_hooks_load "$name"
  info "install component: $name (${COMP_DESC[$name]})"
  component_hook component_pre_install
  apply_links "$name"
  apply_templates "$name"
  record_data_dirs "$name"
  component_hook component_install
  component_hook component_post_install
  component_mark_installed "$name"
  ok "component installed: $name"
}

component_update_one() {
  local name=$1
  component_load "$name"
  component_hooks_load "$name"
  info "update component: $name"
  component_hook component_pre_install
  apply_links "$name"
  apply_templates "$name"
  record_data_dirs "$name"
  component_hook component_update
  component_hook component_post_install
  component_mark_installed "$name"
  ok "component updated: $name"
}

component_uninstall_one() {
  local name=$1
  component_load "$name"
  component_hooks_load "$name"
  info "uninstall component: $name"
  component_hook component_uninstall
}

remove_link_entry() {
  local path=$1 source=$2 actual
  if [[ ! -L $path ]]; then
    if [[ -e $path ]]; then
      warn "skipping modified file (not a symlink): $path"
    fi
    return 0
  fi
  actual=$(readlink -- "$path")
  if [[ $actual != "$source" ]]; then
    warn "skipping symlink changed by user: $path -> $actual"
    return 0
  fi
  info "remove link $path"
  run rm -f -- "$path"
}

remove_template_entry() {
  local path=$1 checksum=$2 actual
  if [[ -L $path ]]; then
    warn "skipping modified file (became a symlink): $path"
    return 0
  fi
  if [[ ! -e $path ]]; then
    return 0
  fi
  actual=$(file_checksum "$path")
  if [[ $actual != "$checksum" ]]; then
    warn "skipping modified rendered file: $path"
    return 0
  fi
  info "remove rendered file $path"
  run rm -f -- "$path"
}

is_preserved_path() {
  local path=$1
  case "$path" in
    "$HOME/.local/share/opencode" | "$HOME/.local/share/opencode/"*) return 0 ;;
    "$HOME/.config/opencode/service.json") return 0 ;;
    "$HOME/.config/opencode/skills" | "$HOME/.config/opencode/skills/"*) return 0 ;;
    "$HOME/.local/state/zsh/history") return 0 ;;
    "$HOME/.tmux/resurrect" | "$HOME/.tmux/resurrect/"*) return 0 ;;
    "$HOME/.local/share/nvim/projects.json") return 0 ;;
    "$HOME/.local/state/nvim" | "$HOME/.local/state/nvim/"*) return 0 ;;
  esac
  return 1
}

remove_data_path() {
  local path=$1
  if is_preserved_path "$path"; then
    info "preserve user data: $path"
    return 0
  fi
  if [[ -e $path || -L $path ]]; then
    assert_safe_remove "$path"
    info "remove data $path"
    run rm -rf -- "$path"
  fi
}

remove_component_paths() {
  local -a lines=()
  local line kind path source checksum _ i
  [[ -f $MANIFEST ]] || return 0
  mapfile -t lines <"$MANIFEST"

  for ((i = ${#lines[@]} - 1; i >= 0; i--)); do
    line=${lines[i]}
    [[ -n $line ]] || continue
    IFS=$'\t' read -r kind path source checksum _ <<<"$line"
    case "$kind" in
      link) remove_link_entry "$path" "$source" ;;
      template) remove_template_entry "$path" "$checksum" ;;
      data) remove_data_path "$path" ;;
      data-existing) debug "leave pre-existing data: $path" ;;
      file)
        if [[ -f $path ]] && { [[ ! -s $path ]] || [[ -n $checksum && $(file_checksum "$path") == "$checksum" ]]; }; then
          info "remove file created by installer $path"
          run rm -f -- "$path"
        fi
        ;;
      dir | backup) : ;;
      *) debug "unknown manifest entry: $kind $path" ;;
    esac
  done

  # Remove created directories only after data directories are gone, deepest
  # first, so empty parents such as ~/.tmux can be cleaned up.
  for ((i = ${#lines[@]} - 1; i >= 0; i--)); do
    line=${lines[i]}
    [[ -n $line ]] || continue
    IFS=$'\t' read -r kind path source checksum _ <<<"$line"
    if [[ $kind == dir && -d $path ]] && [[ -z $(ls -A -- "$path" 2>/dev/null) ]]; then
      info "remove empty directory $path"
      run rmdir -- "$path"
    fi
  done
}

restore_backups() {
  local -a lines=()
  local line kind path source checksum
  [[ -f $MANIFEST ]] || return 0
  mapfile -t lines < <(manifest_entries backup | sort -t $'\t' -k5,5r -k2,2)

  for line in "${lines[@]}"; do
    [[ -n $line ]] || continue
    IFS=$'\t' read -r kind path source checksum _ <<<"$line"
    if [[ ! -e $source ]]; then
      warn "backup is missing: $source"
      continue
    fi
    if [[ -e $path || -L $path ]]; then
      warn "not overwriting existing path with backup: $path"
      continue
    fi
    info "restore backup $path"
    run mkdir -p -- "$(dirname "$path")"
    run mv -- "$source" "$path"
  done
}

block_remove() {
  local file=$1 start=$2 end=$3 tmp mode
  [[ -L $file ]] && file=$(readlink -f -- "$file")
  [[ -f $file ]] || return 0
  mode=$(stat -c '%a' "$file" 2>/dev/null || echo 644)
  tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-block.XXXXXX")
  awk -v start="$start" -v end="$end" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    !skip { print }
  ' "$file" >"$tmp"
  if $DRY_RUN; then
    info "[dry-run] remove managed block from $file"
    rm -f -- "$tmp"
    return 0
  fi
  chmod "$mode" "$tmp"
  mv -- "$tmp" "$file"
}

block_install() {
  local file=$1 start=$2 end=$3 content=$4 tmp mode
  [[ -L $file ]] && file=$(readlink -f -- "$file")
  ensure_parent "$(dirname "$file")"
  if $DRY_RUN; then
    info "[dry-run] write managed block in $file"
    return 0
  fi
  if [[ ! -f $file ]]; then
    : >"$file"
    manifest_add file "$file" "" ""
  fi
  block_remove "$file" "$start" "$end"
  mode=$(stat -c '%a' "$file" 2>/dev/null || echo 644)
  tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-block.XXXXXX")
  cp -- "$file" "$tmp"
  if [[ -s $tmp ]] && [[ $(tail -c 1 "$tmp" | wc -l) -eq 0 ]]; then
    printf '\n' >>"$tmp"
  fi
  {
    printf '%s\n' "$start"
    printf '%s\n' "$content"
    printf '%s\n' "$end"
  } >>"$tmp"
  chmod "$mode" "$tmp"
  mv -- "$tmp" "$file"
}

component_track_tool() {
  local tool=$1
  $DRY_RUN && return 0
  mkdir -p "$STATE_DIR"
  touch "$TOOLS_FILE"
  grep -Fxq -- "$tool" "$TOOLS_FILE" 2>/dev/null || printf '%s\n' "$tool" >>"$TOOLS_FILE"
}

clone_repo() {
  local url=$1 dest=$2
  if [[ -d $dest/.git ]]; then
    debug "repository already exists: $dest"
    return 0
  fi
  ensure_parent "$(dirname "$dest")"
  info "clone $url -> $dest"
  run git clone --depth=1 -- "$url" "$dest"
}

git_pull_repo() {
  local dir=$1
  [[ -d $dir/.git ]] || return 0
  info "pull $dir"
  run git -C "$dir" pull --ff-only
}
