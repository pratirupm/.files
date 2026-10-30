# shellcheck shell=bash
# shellcheck disable=SC2034
# Component discovery, dependency resolution, and deterministic ordering.

COMPONENTS_DIR="${COMPONENTS_DIR:-$DOTFILES_DIR/components}"

COMPONENT_NAMES=()
ORDERED_COMPONENTS=()
SELECTED_COMPONENTS=()
ONLY_COMPONENTS=()

declare -gA COMP_DESC=()
declare -gA COMP_REQUIRES=()
declare -gA COMP_AFTER=()
declare -gA COMP_DEPS=()
declare -gA COMP_LINKS=()
declare -gA COMP_TEMPLATES=()
declare -gA COMP_DATA=()
declare -gA COMP_DIR=()

_lines() {
  (($# == 0)) || printf '%s\n' "$@"
}

component_load() {
  local name=$1 conf="$COMPONENTS_DIR/$1/component.conf"
  [[ -f $conf ]] || die "unknown component: $name"

  NAME="" DESCRIPTION="" REQUIRES=() AFTER=() SYSTEM_DEPS=()
  LINKS=() TEMPLATES=() DATA_DIRS=()
  # Component manifests are trusted files shipped in this repository.
  # shellcheck source=/dev/null
  source "$conf"

  [[ ${NAME:-} == "$name" ]] ||
    die "component.conf for '$name' declares NAME='${NAME:-}'"
  [[ -n ${DESCRIPTION:-} ]] || DESCRIPTION="$name"

  COMP_DESC[$name]=$DESCRIPTION
  COMP_REQUIRES[$name]=$(_lines "${REQUIRES[@]}")
  COMP_AFTER[$name]=$(_lines "${AFTER[@]}")
  COMP_DEPS[$name]=$(_lines "${SYSTEM_DEPS[@]}")
  COMP_LINKS[$name]=$(_lines "${LINKS[@]}")
  COMP_TEMPLATES[$name]=$(_lines "${TEMPLATES[@]}")
  COMP_DATA[$name]=$(_lines "${DATA_DIRS[@]}")
  COMP_DIR[$name]=$COMPONENTS_DIR/$name
}

component_discover() {
  local conf name
  COMPONENT_NAMES=()
  COMP_DESC=() COMP_REQUIRES=() COMP_AFTER=() COMP_DEPS=()
  COMP_LINKS=() COMP_TEMPLATES=() COMP_DATA=() COMP_DIR=()

  shopt -s nullglob
  for conf in "$COMPONENTS_DIR"/*/component.conf; do
    name=$(basename "$(dirname "$conf")")
    component_load "$name"
    COMPONENT_NAMES+=("$name")
  done

  ((${#COMPONENT_NAMES[@]})) || die "no components found in $COMPONENTS_DIR"
  local IFS=$'\n'
  mapfile -t COMPONENT_NAMES < <(printf '%s\n' "${COMPONENT_NAMES[@]}" | sort)
}

_component_exists() {
  local name=$1
  [[ -n ${COMP_DIR[$name]:-} ]]
}

component_validate() {
  local name req
  for name in "${COMPONENT_NAMES[@]}"; do
    for req in ${COMP_REQUIRES[$name]}; do
      _component_exists "$req" || die "component '$name' requires missing component '$req'"
    done
    for req in ${COMP_AFTER[$name]}; do
      _component_exists "$req" || die "component '$name' must run after missing component '$req'"
    done
  done
}

SELECTED_SET=""

component_select() {
  local -a requested=("$@")
  local -a queue=()
  local -A wanted=()
  local name req

  if ((${#requested[@]} == 0)); then
    requested=("${COMPONENT_NAMES[@]}")
  fi

  for name in "${requested[@]}"; do
    _component_exists "$name" || die "unknown component: $name"
    if [[ -z ${wanted[$name]:-} ]]; then
      wanted[$name]=1
      queue+=("$name")
    fi
  done

  while ((${#queue[@]})); do
    name=${queue[0]}
    queue=("${queue[@]:1}")
    for req in ${COMP_REQUIRES[$name]}; do
      _component_exists "$req" || die "component '$name' requires missing component '$req'"
      if [[ -z ${wanted[$req]:-} ]]; then
        wanted[$req]=1
        queue+=("$req")
      fi
    done
  done

  SELECTED_COMPONENTS=()
  SELECTED_SET=""
  for name in "${COMPONENT_NAMES[@]}"; do
    if [[ -n ${wanted[$name]:-} ]]; then
      SELECTED_COMPONENTS+=("$name")
      SELECTED_SET+="$name"$'\n'
    fi
  done
}

component_order() {
  local -a remaining=("${SELECTED_COMPONENTS[@]}")
  local -A completed=()
  local picked name req after ready

  ORDERED_COMPONENTS=()
  while ((${#remaining[@]})); do
    picked=""
    for name in "${remaining[@]}"; do
      ready=true
      for req in ${COMP_REQUIRES[$name]}; do
        [[ -n ${completed[$req]:-} ]] || { ready=false; break; }
      done
      $ready || continue
      for after in ${COMP_AFTER[$name]}; do
        [[ -n ${completed[$after]:-} ]] && continue
        if grep -Fxq -- "$after" <<<"$SELECTED_SET"; then
          ready=false
          break
        fi
      done
      $ready || continue
      picked=$name
      break
    done

    if [[ -z $picked ]]; then
      die "component dependency cycle: ${remaining[*]}"
    fi

    ORDERED_COMPONENTS+=("$picked")
    completed[$picked]=1
    local -a next=()
    for name in "${remaining[@]}"; do
      [[ $name == "$picked" ]] || next+=("$name")
    done
    remaining=("${next[@]}")
  done
}

component_deps() {
  local name=$1 entry tool reason
  while IFS= read -r entry; do
    [[ -n $entry ]] || continue
    tool=${entry%%|*}
    reason=${entry#*|}
    [[ $reason == "$entry" ]] && reason="required by $name"
    printf '%s|%s: %s\n' "$tool" "$name" "$reason"
  done <<<"${COMP_DEPS[$name]}"
}

component_all_deps() {
  local name
  for name in "${ORDERED_COMPONENTS[@]}"; do
    component_deps "$name"
  done
}

component_plan() {
  local only=${1:-}
  local -a requested=()
  local item

  if [[ -n $only ]]; then
    IFS=',' read -ra requested <<<"$only"
    local -a cleaned=()
    for item in "${requested[@]}"; do
      item=$(trim "$item")
      [[ -n $item ]] && cleaned+=("$item")
    done
    ((${#cleaned[@]})) || die "--only requires at least one component"
    requested=("${cleaned[@]}")
  fi

  component_discover
  component_validate
  component_select "${requested[@]}"
  component_order
}
