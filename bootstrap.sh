#!/bin/sh
# URL entrypoint: check the entry requirement, clone or fast-forward, then
# hand off to install.sh. POSIX sh only; no bashisms.
set -eu

REPO_URL=${DOTFILES_REPO_URL:-https://github.com/pratirupm/.files.git}
DEST=${DOTFILES_DIR:-"$HOME/.files"}

say() { printf '%s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
die() {
  err "$*"
  exit 2
}

install_hint() {
  pkg=$1
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  fi
  id=${ID:-unknown}
  like=${ID_LIKE:-}
  variant=${VARIANT_ID:-}
  case " $id $like " in
    *" fedora "* | *" rhel "* | *" centos "* | *" rocky "* | *" almalinux "*)
      case " $variant " in
        *" silverblue "* | *" kinoite "* | *" coreos "* | *" iot "*)
          printf 'sudo rpm-ostree install %s' "$pkg"
          ;;
        *) printf 'sudo dnf install -y %s' "$pkg" ;;
      esac
      ;;
    *" debian "* | *" ubuntu "* | *" linuxmint "*)
      printf 'sudo apt-get install -y %s' "$pkg"
      ;;
    *" arch "* | *" manjaro "*)
      printf 'sudo pacman -S --needed %s' "$pkg"
      ;;
    *" opensuse "* | *" suse "*)
      printf 'sudo zypper install -y %s' "$pkg"
      ;;
    *" alpine "*)
      printf 'sudo apk add %s' "$pkg"
      ;;
    *)
      printf 'install %s with your package manager' "$pkg"
      ;;
  esac
}

command -v git >/dev/null 2>&1 ||
  die "git is required to clone this repository. $(install_hint git)"
if ! command -v curl >/dev/null 2>&1 &&
  ! command -v wget >/dev/null 2>&1 &&
  ! command -v python3 >/dev/null 2>&1 &&
  ! command -v busybox >/dev/null 2>&1; then
  die "an HTTPS fetcher (curl, wget, python3, or busybox) is required. $(install_hint curl)"
fi

if [ -d "$DEST/.git" ]; then
  say "Updating $DEST"
  git -C "$DEST" pull --ff-only ||
    die "could not fast-forward $DEST; commit or discard local changes and retry"
elif [ -e "$DEST" ]; then
  die "$DEST exists but is not a git checkout; move it aside and retry"
else
  say "Cloning $REPO_URL into $DEST"
  git clone --depth=1 -- "$REPO_URL" "$DEST"
fi

[ -x "$DEST/install.sh" ] || die "checkout is missing install.sh: $DEST"
exec "$DEST/install.sh" "$@"
