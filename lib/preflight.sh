# shellcheck shell=bash
# Operating-system detection and prerequisite reporting. This file never
# installs system packages and never invokes sudo.

OS_NAME=""
OS_ID=""
OS_LIKE=""
OS_VERSION=""
OS_VARIANT=""
OS_FAMILY=""
PKG_MANAGER=""
ARCH=""
LIBC=""
GLIBC_VERSION=""
PREFLIGHT_FAILED=0
MISSING_TOOLS=()
declare -gA MISSING_REASONS=()

# Shell commands needed by every component, plus the reason shown to the user.
BASE_DEPS=(
  "git|clone plugins and update the checkout"
  "tar|extract release archives"
  "gzip|extract release archives"
  "xz|extract release archives"
  "bzip2|extract release archives"
  "find|locate runtimes and plugin files"
)

detect_os() {
  local os_release=${DOTFILES_OS_RELEASE:-/etc/os-release}
  local id_like=""
  [[ -r $os_release ]] || die "cannot read $os_release"

  # shellcheck disable=SC1090
  source "$os_release"
  OS_NAME=${PRETTY_NAME:-${NAME:-Linux}}
  OS_ID=${ID:-unknown}
  OS_LIKE=${ID_LIKE:-}
  OS_VERSION=${VERSION_ID:-}
  OS_VARIANT=${VARIANT_ID:-}

  id_like=" $OS_ID $OS_LIKE "
  case "$id_like" in
    *" fedora "* | *" rhel "* | *" centos "* | *" rocky "* | *" almalinux "*)
      OS_FAMILY=fedora
      case " $OS_VARIANT " in
        *" silverblue "* | *" kinoite "* | *" coreos "* | *" iot "*)
          PKG_MANAGER=rpm-ostree
          ;;
        *) PKG_MANAGER=dnf ;;
      esac
      ;;
    *" debian "* | *" ubuntu "* | *" linuxmint "* | *" pop "* | *" raspbian "*)
      OS_FAMILY=debian
      PKG_MANAGER=apt
      ;;
    *" arch "* | *" endeavouros "* | *" manjaro "*)
      OS_FAMILY=arch
      PKG_MANAGER=pacman
      ;;
    *" opensuse "* | *" suse "* | *" sles "*)
      OS_FAMILY=suse
      PKG_MANAGER=zypper
      ;;
    *" alpine "*)
      OS_FAMILY=alpine
      PKG_MANAGER=apk
      ;;
    *" nixos "*)
      OS_FAMILY=nixos
      PKG_MANAGER=""
      ;;
    *)
      OS_FAMILY=unknown
      PKG_MANAGER=""
      ;;
  esac

  if [[ -n ${DOTFILES_PKG_MANAGER:-} ]]; then
    PKG_MANAGER=$DOTFILES_PKG_MANAGER
  fi
}

detect_arch() {
  ARCH=${DOTFILES_ARCH:-$(uname -m)}
  case "$ARCH" in
    amd64) ARCH=x86_64 ;;
    arm64) ARCH=aarch64 ;;
  esac
}

detect_libc() {
  local ldd_out=""
  LIBC=${DOTFILES_LIBC:-}
  GLIBC_VERSION=${DOTFILES_GLIBC:-}

  if [[ -z $LIBC ]]; then
    if command -v getconf >/dev/null 2>&1 &&
      ldd_out=$(getconf GNU_LIBC_VERSION 2>/dev/null) &&
      [[ $ldd_out == glibc* ]]; then
      LIBC=glibc
      GLIBC_VERSION=${ldd_out##* }
    elif command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | head -1 | grep -qi musl; then
      LIBC=musl
    elif compgen -G "/lib/ld-musl-*" >/dev/null; then
      LIBC=musl
    else
      LIBC=unknown
    fi
  fi

  if [[ $LIBC == glibc && -z $GLIBC_VERSION ]] && command -v getconf >/dev/null 2>&1; then
    GLIBC_VERSION=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
  fi
}

version_ge() {
  local have=$1 want=$2
  [[ -n $have ]] || return 1
  [[ $(printf '%s\n%s\n' "$want" "$have" | sort -V | head -1) == "$want" ]]
}

_preflight_fail() {
  local message=$1
  if [[ ${PREFLIGHT_SOFT:-0} == 1 ]]; then
    error "$message"
    PREFLIGHT_FAILED=1
  else
    DIE_CODE=2 die "$message"
  fi
}

preflight_platform() {
  detect_os
  detect_arch
  detect_libc

  if [[ $ARCH != x86_64 && $ARCH != aarch64 ]]; then
    _preflight_fail "unsupported architecture: $ARCH (supported: x86_64, aarch64)"
  fi

  if [[ $LIBC == musl ]]; then
    _preflight_fail "musl libc detected; this dotfiles repository supports glibc Linux only (Alpine is not supported). Use a glibc distribution or container."
  elif [[ $LIBC == glibc ]]; then
    if ! version_ge "$GLIBC_VERSION" "2.34"; then
      _preflight_fail "glibc $GLIBC_VERSION is too old (Neovim 0.12.6 needs glibc >= 2.34)"
    fi
  elif [[ $LIBC != unknown ]]; then
    _preflight_fail "unsupported libc: $LIBC"
  fi

  if [[ $OS_FAMILY == nixos ]]; then
    _preflight_fail "NixOS is not supported: this repository only writes under \$HOME and does not use /nix"
  fi

  if [[ ${DOTFILES_SKIP_NOEXEC:-0} != 1 ]] && command -v findmnt >/dev/null 2>&1; then
    local options
    options=$(findmnt -n -o OPTIONS -T "$HOME" 2>/dev/null || true)
    if [[ ,$options, == *,noexec,* ]]; then
      _preflight_fail "\$HOME is mounted noexec; downloaded binaries cannot run there"
    fi
  fi

  if command -v df >/dev/null 2>&1; then
    local free_kb
    free_kb=$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n $free_kb ]] && ((free_kb < 2097152)); then
      warn "$(human_kb "$free_kb") free under \$HOME; the install usually needs about 2 GiB"
    fi
  fi
}

preflight_report_header() {
  local libc_desc="libc unknown"
  if [[ $LIBC == glibc ]]; then
    libc_desc="glibc ${GLIBC_VERSION:-?}"
  elif [[ $LIBC == musl ]]; then
    libc_desc="musl"
  fi
  local version_suffix=""
  [[ -n $OS_VERSION ]] && version_suffix=" $OS_VERSION"
  log "${C_BOLD}Detected:${C_RESET} $OS_NAME ($OS_FAMILY$version_suffix), $ARCH, $libc_desc"
}

add_missing_tool() {
  local tool=$1 reason=$2
  if [[ -n ${MISSING_REASONS[$tool]:-} ]]; then
    MISSING_REASONS[$tool]+="; $reason"
  else
    MISSING_REASONS[$tool]=$reason
    MISSING_TOOLS+=("$tool")
  fi
}

check_tool() {
  local tool=$1 reason=$2
  if [[ $tool == ca-certificates ]]; then
    if [[ ! -e /etc/pki/tls/certs/ca-bundle.crt &&
      ! -e /etc/ssl/certs/ca-certificates.crt &&
      ! -e /etc/ssl/cert.pem ]]; then
      add_missing_tool "$tool" "$reason"
    fi
    return 0
  fi
  if ! command -v "$tool" >/dev/null 2>&1; then
    add_missing_tool "$tool" "$reason"
  fi
}

pkg_for() {
  local tool=$1
  case "$PKG_MANAGER" in
    dnf | rpm-ostree)
      case "$tool" in
        find) printf '%s' findutils ;;
        ca-certificates) printf '%s' ca-certificates ;;
        xz) printf '%s' xz ;;
        *) printf '%s' "$tool" ;;
      esac
      ;;
    apt)
      case "$tool" in
        gcc | make) printf '%s' build-essential ;;
        find) printf '%s' findutils ;;
        xz) printf '%s' xz-utils ;;
        ca-certificates) printf '%s' ca-certificates ;;
        *) printf '%s' "$tool" ;;
      esac
      ;;
    pacman)
      case "$tool" in
        gcc | make) printf '%s' base-devel ;;
        find) printf '%s' findutils ;;
        xz) printf '%s' xz ;;
        ca-certificates) printf '%s' ca-certificates ;;
        *) printf '%s' "$tool" ;;
      esac
      ;;
    zypper)
      case "$tool" in
        find) printf '%s' findutils ;;
        xz) printf '%s' xz ;;
        ca-certificates) printf '%s' ca-certificates ;;
        *) printf '%s' "$tool" ;;
      esac
      ;;
    apk)
      case "$tool" in
        gcc | make) printf '%s' build-base ;;
        find) printf '%s' findutils ;;
        xz) printf '%s' xz ;;
        ca-certificates) printf '%s' ca-certificates ;;
        *) printf '%s' "$tool" ;;
      esac
      ;;
    *) printf '%s' "$tool" ;;
  esac
}

preflight_install_command() {
  local -a package_args=("$@")
  case "$PKG_MANAGER" in
    dnf) printf 'sudo dnf install -y %s' "${package_args[*]}" ;;
    rpm-ostree) printf 'sudo rpm-ostree install %s' "${package_args[*]}" ;;
    apt) printf 'sudo apt-get install -y %s' "${package_args[*]}" ;;
    pacman) printf 'sudo pacman -S --needed %s' "${package_args[*]}" ;;
    zypper) printf 'sudo zypper install -y %s' "${package_args[*]}" ;;
    apk) printf 'sudo apk add %s' "${package_args[*]}" ;;
    *) printf 'install with your package manager: %s' "${package_args[*]}" ;;
  esac
}

preflight_dependencies() {
  local entry tool reason name
  local -A seen=()
  MISSING_REASONS=()
  MISSING_TOOLS=()

  for entry in "${BASE_DEPS[@]}"; do
    tool=${entry%%|*}
    reason=${entry#*|}
    check_tool "$tool" "$reason"
  done
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1 &&
    ! command -v python3 >/dev/null 2>&1 && ! command -v busybox >/dev/null 2>&1; then
    add_missing_tool curl "download mise, micromamba, and release archives"
  fi
  check_tool ca-certificates "HTTPS certificate verification"

  while IFS= read -r entry; do
    [[ -n $entry ]] || continue
    name=${entry%%|*}
    reason=${entry#*|}
    [[ -n ${seen[$name]:-} ]] && continue
    seen[$name]=1
    check_tool "$name" "$reason"
  done < <(component_all_deps)

  ((${#MISSING_TOOLS[@]})) || return 0

  log ""
  log "${C_BOLD}Missing system tools:${C_RESET}"
  while IFS= read -r tool; do
    [[ -n $tool ]] && printf '  %-10s %s\n' "$tool" "${MISSING_REASONS[$tool]}"
  done < <(printf '%s\n' "${MISSING_TOOLS[@]}" | sort)

  local -A packages=()
  local -a package_list=()
  local pkg
  for tool in "${MISSING_TOOLS[@]}"; do
    pkg=$(pkg_for "$tool")
    if [[ -n $pkg && -z ${packages[$pkg]:-} ]]; then
      packages[$pkg]=1
      package_list+=("$pkg")
    fi
  done
  mapfile -t package_list < <(printf '%s\n' "${package_list[@]}" | sort)

  log ""
  log "${C_BOLD}Install with:${C_RESET}"
  log "  $(preflight_install_command "${package_list[@]}")"
  log ""

  if [[ ${PREFLIGHT_SOFT:-0} == 1 ]]; then
    PREFLIGHT_FAILED=1
    return 1
  fi
  DIE_CODE=2 die "missing system prerequisites; install them and re-run"
}

preflight_run() {
  PREFLIGHT_SOFT=${1:-0}
  PREFLIGHT_FAILED=0
  preflight_platform
  preflight_report_header
  preflight_dependencies || true
  [[ $PREFLIGHT_FAILED == 0 ]]
}
