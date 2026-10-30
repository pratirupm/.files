#!/usr/bin/env bash
set -Eeuo pipefail

DIR=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)
export DOTFILES_DIR="$DIR"
exec "$DIR/bin/dotfiles" install "$@"
