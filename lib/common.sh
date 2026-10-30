# shellcheck shell=bash
# shellcheck disable=SC2034
# Shared helpers: logging, locking, dry-run execution, and safe paths.

: "${DOTFILES_DIR:?DOTFILES_DIR must be set}"
: "${HOME:?HOME must be set}"

STATE_DIR="${DOTFILES_STATE_DIR:-$HOME/.local/state/dotfiles}"
MANIFEST="$STATE_DIR/manifest.tsv"
BACKUPS_DIR="$STATE_DIR/backups"
INSTALLED_DIR="$STATE_DIR/installed"
LOG_DIR="$STATE_DIR/logs"
TOOLS_FILE="$STATE_DIR/tools.tsv"
LOCK_FILE="$STATE_DIR/lock"
LOCK_DIR="$STATE_DIR/lock.d"

DRY_RUN="${DRY_RUN:-false}"
ASSUME_YES="${ASSUME_YES:-false}"
RUN_ID="${RUN_ID:-$(date +%Y%m%dT%H%M%S)-$$}"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_DIM=$'\033[2m'
else
  C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_DIM=""
fi

log() { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s ok %s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
error() { printf '%serr %s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die() {
  error "$*"
  exit "${DIE_CODE:-1}"
}
debug() {
  [[ ${DOTFILES_DEBUG:-0} == 1 ]] && printf '%sdebug%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
  return 0
}

run() {
  if $DRY_RUN; then
    printf '%s[dry-run]%s' "$C_YELLOW" "$C_RESET"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

run_shell() {
  local cmd=$1
  if $DRY_RUN; then
    printf '%s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$cmd"
    return 0
  fi
  bash -c "$cmd"
}

http_get() {
  local url=$1 output=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$output" -- "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$output" -- "$url"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$url" "$output" <<'PY'
import sys
import urllib.request

urllib.request.urlretrieve(sys.argv[1], sys.argv[2])
PY
  elif command -v busybox >/dev/null 2>&1; then
    busybox wget -qO "$output" "$url"
  else
    die "no HTTPS fetcher found (curl, wget, python3, or busybox)"
  fi
}

prompt_yes() {
  local prompt=$1 answer
  if [[ ! -r /dev/tty ]]; then
    return 1
  fi
  printf '%s [y/N] ' "$prompt" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  [[ $answer =~ ^[Yy]([Ee][Ss])?$ ]]
}

confirm_or_die() {
  local prompt=$1
  if $ASSUME_YES; then
    return 0
  fi
  if prompt_yes "$prompt"; then
    return 0
  fi
  die "aborted; pass --yes to run non-interactively"
}

file_checksum() {
  local file=$1
  if [[ ! -f $file ]]; then
    printf '%s' "-"
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -- "$file" | awk '{print $NF}'
  else
    die "no SHA-256 tool found (sha256sum, shasum, or openssl)"
  fi
}

abs_path() {
  local path=$1
  if command -v realpath >/dev/null 2>&1; then
    realpath -m -- "$path"
  else
    (cd "$(dirname "$path")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$path")") ||
      printf '%s\n' "$path"
  fi
}

assert_under_home() {
  local path=$1
  [[ $path == "$HOME" || $path == "$HOME/"* ]] ||
    die "refusing to touch a path outside \$HOME: $path"
}

assert_safe_remove() {
  local path=$1
  [[ -n $path ]] || die "refusing to remove an empty path"
  [[ $path != "/" && $path != "$HOME" ]] || die "refusing to remove $path"
  assert_under_home "$path"
}

state_init() {
  if $DRY_RUN; then
    return 0
  fi
  mkdir -p "$STATE_DIR" "$BACKUPS_DIR" "$INSTALLED_DIR" "$LOG_DIR"
  touch "$MANIFEST"
}

acquire_lock() {
  $DRY_RUN && return 0
  mkdir -p "$STATE_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
      die "another dotfiles operation is running (lock: $LOCK_FILE)"
    fi
    LOCK_HELD=flock
  else
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      die "another dotfiles operation is running (lock: $LOCK_DIR)"
    fi
    LOCK_HELD=dir
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
  fi
  trap release_lock EXIT INT TERM HUP
}

release_lock() {
  case "${LOCK_HELD:-}" in
    flock) flock -u 9 2>/dev/null || true ;;
    dir) rm -rf -- "$LOCK_DIR" 2>/dev/null || true ;;
  esac
  LOCK_HELD=""
}

timestamp() {
  date +%Y-%m-%dT%H:%M:%S
}

require_command() {
  local cmd=$1 hint=${2:-}
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "required command not found: $cmd${hint:+ ($hint)}"
  fi
}

join_by() {
  local sep=$1
  shift
  local first=true item
  for item in "$@"; do
    if $first; then
      printf '%s' "$item"
      first=false
    else
      printf '%s%s' "$sep" "$item"
    fi
  done
}

trim() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

human_kb() {
  local kb=$1
  if ((kb >= 1048576)); then
    printf '%s GiB' "$((kb / 1048576))"
  elif ((kb >= 1024)); then
    printf '%s MiB' "$((kb / 1024))"
  else
    printf '%s KiB' "$kb"
  fi
}
