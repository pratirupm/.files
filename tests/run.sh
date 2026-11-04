#!/usr/bin/env bash
# Hermetic lifecycle tests. Every test uses a throwaway HOME and stubs; the
# host configuration is never touched.
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
REAL_GIT=$(command -v git)
ORIGINAL_PATH=$PATH
PASS=0

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  PASS=$((PASS + 1))
  printf 'ok   %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

assert_file() {
  [[ -f $1 ]] || fail "expected file: $1"
}

assert_link() {
  [[ -L $1 ]] || fail "expected symlink: $1"
  [[ $(readlink -- "$1") == "$2" ]] || fail "wrong link target for $1: $(readlink -- "$1")"
}

assert_no_link() {
  [[ ! -L $1 ]] || fail "unexpected symlink: $1"
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
  grep -Fq -- "$2" "$1" && fail "did not expect '$2' in $1"
  return 0
}

make_stubs() {
  local dir=$1
  mkdir -p "$dir"

  cat >"$dir/micromamba" <<'EOF'
#!/bin/bash
set -e
if [[ ${1:-} == create ]]; then
  while (($#)); do
    if [[ $1 == -p ]]; then
      p=$2
      break
    fi
    shift
  done
  mkdir -p "$p/bin"
  printf '#!/bin/sh\necho "zsh 5.9"\n' >"$p/bin/zsh"
  chmod +x "$p/bin/zsh"
fi
exit 0
EOF

  cat >"$dir/git" <<EOF
#!/bin/bash
set -e
if [[ \${1:-} == clone ]]; then
  dest=\${!#}
  mkdir -p "\$dest"
  "$REAL_GIT" -C "\$dest" init -q
  case "\$dest" in
    */oh-my-zsh) touch "\$dest/oh-my-zsh.sh" ;;
    */plugins/tpm)
      printf '#!/bin/sh\nexit 0\n' >"\$dest/tpm"
      chmod +x "\$dest/tpm"
      ;;
  esac
  exit 0
fi
exec "$REAL_GIT" "\$@"
EOF

  cat >"$dir/nvim" <<'EOF'
#!/bin/bash
mkdir -p "$HOME/.local/share/nvim/lazy" "$HOME/.local/share/nvim/mason" "$HOME/.local/share/nvim/base46"
printf 'NVIM v0.12.6\n'
EOF

  cat >"$dir/tmux" <<'EOF'
#!/bin/bash
printf 'tmux 3.7c\n'
EOF

  cat >"$dir/opencode" <<'EOF'
#!/bin/bash
printf 'opencode v2.2.4\n'
EOF

  cat >"$dir/bun" <<'EOF'
#!/bin/bash
if [[ ${1:-} == install ]]; then
  mkdir -p node_modules/@opencode/plugin
fi
printf '1.4.4\n'
EOF

  cat >"$dir/bunx" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$HOME/bunx.log"
version=""
for arg in "$@"; do
  case "$arg" in
    playwright@*) version=${arg#playwright@} ;;
  esac
done
if [[ -n $version ]]; then
  mkdir -p "$HOME/.cache/ms-playwright/chromium-$version/chrome-linux64"
  printf '#!/bin/sh\nexit 0\n' >"$HOME/.cache/ms-playwright/chromium-$version/chrome-linux64/chrome"
  chmod +x "$HOME/.cache/ms-playwright/chromium-$version/chrome-linux64/chrome"
fi
exit 0
EOF

  cat >"$dir/node" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$dir/mise" <<'EOF'
#!/bin/bash
set -e
case "${1:-}" in
  upgrade) printf '\n# test upgrade\n' >>"$(pwd)/mise.lock" ;;
esac
exit 0
EOF

  chmod +x "$dir"/*
}

new_home() {
  local name=$1
  HOME="$TEST_ROOT/home-$name"
  rm -rf -- "$HOME"
  mkdir -p "$HOME/.opencode/bin"
  cp "$STUBS/opencode" "$HOME/.opencode/bin/opencode"
  export HOME
  export DOTFILES_SKIP_TOOLCHAIN=1
  export DOTFILES_SKIP_NOEXEC=1
  export DOTFILES_SKIP_OPENCODE_INSTALL=1
  export DOTFILES_SKIP_BROWSER=1
  export PATH="$STUBS:$ORIGINAL_PATH"
}

make_stubs "$TEST_ROOT/stubs"
STUBS="$TEST_ROOT/stubs"

# ---------------------------------------------------------------------------
# preflight rejects musl and old glibc before installing.
# ---------------------------------------------------------------------------
new_home libc
set +e
DOTFILES_LIBC=musl "$ROOT/bin/dotfiles" install --dry-run --only core >"$TEST_ROOT/musl.log" 2>&1
code=$?
set -e
[[ $code -eq 2 ]] || fail "musl preflight exit code was $code"
assert_contains "$TEST_ROOT/musl.log" "musl libc detected"

set +e
DOTFILES_LIBC=glibc DOTFILES_GLIBC=2.31 "$ROOT/bin/dotfiles" install --dry-run --only core >"$TEST_ROOT/glibc.log" 2>&1
code=$?
set -e
[[ $code -eq 2 ]] || fail "old glibc preflight exit code was $code"
assert_contains "$TEST_ROOT/glibc.log" "glibc 2.31 is too old"
pass "preflight rejects musl and glibc < 2.34"

# ---------------------------------------------------------------------------
# Dry-run makes no changes.
# ---------------------------------------------------------------------------
new_home dryrun
"$ROOT/bin/dotfiles" install --dry-run --yes --only core >"$TEST_ROOT/dryrun.log" 2>&1 ||
  fail "dry-run failed"
[[ ! -e "$HOME/.bashrc" ]] || fail "dry-run created .bashrc"
[[ ! -e "$HOME/.local/state/dotfiles/manifest.tsv" ]] || fail "dry-run created a manifest"
[[ ! -e "$HOME/.local/bin/dotfiles" ]] || fail "dry-run created a symlink"
pass "dry-run leaves the home untouched"

# ---------------------------------------------------------------------------
# --only includes REQUIRES/AFTER dependencies and excludes unrelated components.
# ---------------------------------------------------------------------------
new_home only
"$ROOT/bin/dotfiles" install --dry-run --yes --only tmux >"$TEST_ROOT/only.log" 2>&1 ||
  fail "--only dry-run failed"
assert_contains "$TEST_ROOT/only.log" "install component: core"
assert_contains "$TEST_ROOT/only.log" "install component: zsh"
assert_contains "$TEST_ROOT/only.log" "install component: tmux"
assert_not_contains "$TEST_ROOT/only.log" "install component: nvim"
assert_not_contains "$TEST_ROOT/only.log" "install component: opencode"
pass "--only resolves dependencies and skips unrelated components"

# ---------------------------------------------------------------------------
# Full install, doctor, and backup/restore.
# ---------------------------------------------------------------------------
new_home install
printf 'original bashrc\n' >"$HOME/.bashrc"
mkdir -p "$HOME/.config/nvim" "$HOME/.local/share/nvim/lazy"
printf 'original nvim\n' >"$HOME/.config/nvim/init.lua"
printf 'user plugin\n' >"$HOME/.local/share/nvim/lazy/user-file"

"$ROOT/bin/dotfiles" install --yes >"$TEST_ROOT/install.log" 2>&1 ||
  fail "install failed: $(tail -20 "$TEST_ROOT/install.log")"

for link in \
  "$HOME/.local/bin/dotfiles:$ROOT/bin/dotfiles" \
  "$HOME/.config/nvim:$ROOT/components/nvim" \
  "$HOME/.zshenv:$ROOT/components/zsh/zshenv" \
  "$HOME/.config/zsh/.zshrc:$ROOT/components/zsh/zshrc" \
  "$HOME/.config/starship.toml:$ROOT/components/zsh/starship.toml" \
  "$HOME/.config/opencode/opencode.json:$ROOT/components/opencode/opencode.json" \
  "$HOME/.config/opencode/themes/vague.json:$ROOT/components/opencode/themes/vague.json" \
  "$HOME/.config/tmux/vague.conf:$ROOT/components/tmux/vague.conf"; do
  assert_link "${link%%:*}" "${link#*:}"
done

assert_contains "$HOME/.bashrc" "# >>> dotfiles >>>"
assert_contains "$HOME/.bashrc" "original bashrc"
assert_contains "$HOME/.tmux.conf" "$HOME/.local/bin/zsh"
assert_not_contains "$HOME/.tmux.conf" "\${HOME}"
assert_file "$HOME/.local/share/oh-my-zsh/oh-my-zsh.sh"
assert_file "$HOME/.tmux/plugins/tpm/tpm"
assert_file "$HOME/.local/state/dotfiles/installed/nvim"
assert_file "$HOME/.local/state/dotfiles/manifest.tsv"

"$ROOT/bin/dotfiles" doctor >"$TEST_ROOT/doctor.log" 2>&1 ||
  fail "doctor failed: $(tail -20 "$TEST_ROOT/doctor.log")"
pass "full install, links, template rendering, and doctor"

backup_count=$(find "$HOME/.local/state/dotfiles/backups" -type f | wc -l)
[[ $backup_count -ge 1 ]] || fail "expected a backup of existing nvim config"
"$ROOT/bin/dotfiles" uninstall --yes >"$TEST_ROOT/uninstall.log" 2>&1 ||
  fail "uninstall failed: $(tail -20 "$TEST_ROOT/uninstall.log")"
[[ $(find "$HOME" -type l | wc -l) -eq 0 ]] || fail "dangling symlinks remain after uninstall"
[[ $(cat "$HOME/.config/nvim/init.lua") == "original nvim" ]] || fail "nvim backup was not restored"
assert_contains "$HOME/.bashrc" "original bashrc"
assert_not_contains "$HOME/.bashrc" "# >>> dotfiles >>>"
assert_file "$HOME/.local/share/nvim/lazy/user-file"
[[ $(cat "$HOME/.local/share/nvim/lazy/user-file") == "user plugin" ]] ||
  fail "pre-existing data dir was modified"
pass "uninstall removes managed paths, removes blocks, restores backups, keeps pre-existing data"

# ---------------------------------------------------------------------------
# opencode uses the official installer, installs matching Chromium, and prunes
# the old custom-agent links.
# ---------------------------------------------------------------------------
new_home opencode
rm -rf "$HOME/.opencode"
mkdir -p "$HOME/.config/opencode/agents"
ln -s "$ROOT/components/opencode/agents/planner.md" "$HOME/.config/opencode/agents/planner.md"
ln -s "$ROOT/components/opencode/AGENTS.md" "$HOME/.config/opencode/AGENTS.md"
cat >"$TEST_ROOT/fake-opencode-installer" <<'EOF'
#!/bin/bash
set -e
[[ ${1:-} == --no-modify-path ]] || {
  echo "--no-modify-path missing" >&2
  exit 1
}
mkdir -p "$HOME/.opencode/bin"
printf '#!/bin/sh\necho "opencode v2.2.5"\n' >"$HOME/.opencode/bin/opencode"
chmod +x "$HOME/.opencode/bin/opencode"
printf '#!/bin/sh\nexec "$(dirname "$0")/opencode" "$@"\n' >"$HOME/.opencode/bin/opencode2"
chmod +x "$HOME/.opencode/bin/opencode2"
EOF
chmod +x "$TEST_ROOT/fake-opencode-installer"
DOTFILES_SKIP_OPENCODE_INSTALL=0 DOTFILES_SKIP_BROWSER=0 DOTFILES_PLAYWRIGHT_VERSION=9.9.9 \
  DOTFILES_OPENCODE_INSTALLER="$TEST_ROOT/fake-opencode-installer" \
  "$ROOT/bin/dotfiles" install --yes --only opencode >"$TEST_ROOT/opencode-install.log" 2>&1 ||
  fail "opencode install failed: $(tail -20 "$TEST_ROOT/opencode-install.log")"
assert_file "$HOME/.opencode/bin/opencode"
assert_file "$HOME/.opencode/bin/opencode2"
assert_file "$HOME/.local/state/dotfiles/opencode-installed"
assert_contains "$HOME/bunx.log" "playwright@9.9.9 install chromium"
assert_file "$HOME/.cache/ms-playwright/chromium-9.9.9/chrome-linux64/chrome"
assert_no_link "$HOME/.config/opencode/agents/planner.md"
assert_no_link "$HOME/.config/opencode/AGENTS.md"
[[ ! -e "$HOME/.config/opencode/agents" ]] || fail "legacy agents directory remains"
DOTFILES_SKIP_BROWSER=0 "$ROOT/bin/dotfiles" doctor --only opencode >"$TEST_ROOT/opencode-doctor.log" 2>&1 ||
  fail "opencode doctor failed: $(tail -20 "$TEST_ROOT/opencode-doctor.log")"
pass "opencode uses the official installer, installs matching Chromium, and prunes legacy links"

# ---------------------------------------------------------------------------
# Doctor fails on a broken link and install repairs it.
# ---------------------------------------------------------------------------
new_home repair
"$ROOT/bin/dotfiles" install --yes --only core >"$TEST_ROOT/repair-install.log" 2>&1 ||
  fail "core install failed"
rm -f "$HOME/.local/bin/dotfiles"
if "$ROOT/bin/dotfiles" doctor --only core >"$TEST_ROOT/repair-doctor.log" 2>&1; then
  fail "doctor accepted a missing managed symlink"
fi
"$ROOT/bin/dotfiles" install --yes --only core >"$TEST_ROOT/repair2.log" 2>&1 ||
  fail "repair install failed"
"$ROOT/bin/dotfiles" doctor --only core >"$TEST_ROOT/repair3.log" 2>&1 ||
  fail "doctor failed after repair"
assert_link "$HOME/.local/bin/dotfiles" "$ROOT/bin/dotfiles"
pass "doctor detects broken links and install repairs them"

# ---------------------------------------------------------------------------
# Update installs a newly added component without a marker.
# ---------------------------------------------------------------------------
new_home update
UPDATE_REPO="$HOME/.files"
cp -a "$ROOT/." "$UPDATE_REPO"
rm -rf "$UPDATE_REPO/.git"
DOTFILES_DIR="$UPDATE_REPO" "$UPDATE_REPO/bin/dotfiles" install --yes --only core >"$TEST_ROOT/update-install.log" 2>&1 ||
  fail "update fixture install failed"

mkdir -p "$UPDATE_REPO/components/fake"
cat >"$UPDATE_REPO/components/fake/component.conf" <<'EOF'
NAME="fake"
DESCRIPTION="update fixture"
REQUIRES=("core")
AFTER=("core")
SYSTEM_DEPS=()
LINKS=("$DOTFILES/components/fake/file|$HOME/.fake")
TEMPLATES=()
DATA_DIRS=()
EOF
printf 'fake\n' >"$UPDATE_REPO/components/fake/file"
cat >"$UPDATE_REPO/components/fake/hooks.sh" <<'EOF'
component_install() { printf 'installed\n' > "$HOME/.fake-hook"; }
component_update() { printf 'updated\n' > "$HOME/.fake-hook"; }
EOF

DOTFILES_DIR="$UPDATE_REPO" DOTFILES_SKIP_PULL=1 "$UPDATE_REPO/bin/dotfiles" update --yes >"$TEST_ROOT/update.log" 2>&1 ||
  fail "update failed: $(tail -20 "$TEST_ROOT/update.log")"
assert_link "$HOME/.fake" "$UPDATE_REPO/components/fake/file"
[[ $(cat "$HOME/.fake-hook") == "installed" ]] || fail "new component did not use install path"
assert_file "$HOME/.local/state/dotfiles/installed/fake"
pass "update installs a new component via the install path"

# ---------------------------------------------------------------------------
# Purge removes the checkout and state but preserves user data.
# ---------------------------------------------------------------------------
new_home purge
PURGE_REPO="$HOME/.files"
cp -a "$ROOT/." "$PURGE_REPO"
rm -rf "$PURGE_REPO/.git"
mkdir -p "$HOME/.local/share/opencode" "$HOME/.config/opencode/skills" \
  "$HOME/.local/state/zsh" "$HOME/.tmux/resurrect" "$HOME/.local/share/nvim" \
  "$HOME/.local/state/nvim"
printf 'auth\n' >"$HOME/.local/share/opencode/auth.json"
printf 'secret\n' >"$HOME/.config/opencode/service.json"
printf 'skill\n' >"$HOME/.config/opencode/skills/x.md"
printf 'history\n' >"$HOME/.local/state/zsh/history"
printf 'resurrect\n' >"$HOME/.tmux/resurrect/state"
printf 'projects\n' >"$HOME/.local/share/nvim/projects.json"
printf 'shada\n' >"$HOME/.local/state/nvim/shada"

DOTFILES_DIR="$PURGE_REPO" "$PURGE_REPO/bin/dotfiles" install --yes >"$TEST_ROOT/purge-install.log" 2>&1 ||
  fail "purge fixture install failed"
touch "$HOME/.local/state/dotfiles/opencode-installed"
DOTFILES_DIR="$PURGE_REPO" "$PURGE_REPO/bin/dotfiles" uninstall --purge --yes >"$TEST_ROOT/purge.log" 2>&1 ||
  fail "purge failed: $(tail -20 "$TEST_ROOT/purge.log")"

[[ ! -e $PURGE_REPO ]] || fail "purge left the checkout behind"
[[ ! -e "$HOME/.local/state/dotfiles" ]] || fail "purge left recovery state behind"
[[ ! -e "$HOME/.opencode/bin/opencode" ]] || fail "purge left the official opencode binary behind"
assert_file "$HOME/.local/share/opencode/auth.json"
assert_file "$HOME/.config/opencode/service.json"
assert_file "$HOME/.config/opencode/skills/x.md"
assert_file "$HOME/.local/state/zsh/history"
assert_file "$HOME/.tmux/resurrect/state"
assert_file "$HOME/.local/share/nvim/projects.json"
assert_file "$HOME/.local/state/nvim/shada"
pass "purge removes checkout/state and preserves user data"

# ---------------------------------------------------------------------------
# Upgrade verifies, commits tracked lockfile changes, and pushes.
# ---------------------------------------------------------------------------
new_home upgrade
UPGRADE_REPO="$HOME/.files"
cp -a "$ROOT/." "$UPGRADE_REPO"
rm -rf "$UPGRADE_REPO/.git"
"$REAL_GIT" init -q -b main "$UPGRADE_REPO"
"$REAL_GIT" -C "$UPGRADE_REPO" config user.email test@example.com
"$REAL_GIT" -C "$UPGRADE_REPO" config user.name Test
"$REAL_GIT" -C "$UPGRADE_REPO" add -A
"$REAL_GIT" -C "$UPGRADE_REPO" commit -qm initial
"$REAL_GIT" init -q --bare "$TEST_ROOT/upstream.git"
"$REAL_GIT" -C "$UPGRADE_REPO" remote add origin "$TEST_ROOT/upstream.git"
"$REAL_GIT" -C "$UPGRADE_REPO" push -qu origin main

DOTFILES_DIR="$UPGRADE_REPO" "$UPGRADE_REPO/bin/dotfiles" install --yes --only core >"$TEST_ROOT/upgrade-install.log" 2>&1 ||
  fail "upgrade fixture install failed"
DOTFILES_DIR="$UPGRADE_REPO" "$UPGRADE_REPO/bin/dotfiles" upgrade >"$TEST_ROOT/upgrade.log" 2>&1 ||
  fail "upgrade failed: $(tail -20 "$TEST_ROOT/upgrade.log")"
"$REAL_GIT" -C "$UPGRADE_REPO" log --oneline -1 | grep -Fq "chore: upgrade tools" ||
  fail "upgrade did not create its commit"
"$REAL_GIT" -C "$TEST_ROOT/upstream.git" log --oneline -1 main | grep -Fq "chore: upgrade tools" ||
  fail "upgrade did not push its commit"

printf '\ndirty\n' >>"$UPGRADE_REPO/README.md"
set +e
DOTFILES_DIR="$UPGRADE_REPO" "$UPGRADE_REPO/bin/dotfiles" upgrade >"$TEST_ROOT/upgrade-dirty.log" 2>&1
code=$?
set -e
[[ $code -ne 0 ]] || fail "upgrade accepted a dirty tree"
"$REAL_GIT" -C "$UPGRADE_REPO" checkout -- README.md
pass "upgrade commits/pushes lock changes and rejects dirty trees"

# ---------------------------------------------------------------------------
# Bootstrap clones and fast-forwards.
# ---------------------------------------------------------------------------
new_home bootstrap
BOOT_SRC="$TEST_ROOT/boot-src"
cp -a "$ROOT/." "$BOOT_SRC"
rm -rf "$BOOT_SRC/.git"
"$REAL_GIT" init -q -b main "$BOOT_SRC"
"$REAL_GIT" -C "$BOOT_SRC" config user.email test@example.com
"$REAL_GIT" -C "$BOOT_SRC" config user.name Test
"$REAL_GIT" -C "$BOOT_SRC" add -A
"$REAL_GIT" -C "$BOOT_SRC" commit -qm initial

PATH="$ORIGINAL_PATH" DOTFILES_REPO_URL="$BOOT_SRC" sh "$ROOT/bootstrap.sh" --dry-run --only core >"$TEST_ROOT/bootstrap.log" 2>&1 ||
  fail "bootstrap failed: $(tail -20 "$TEST_ROOT/bootstrap.log")"
[[ -x "$HOME/.files/install.sh" ]] || fail "bootstrap did not create a checkout"
PATH="$ORIGINAL_PATH" DOTFILES_REPO_URL="$BOOT_SRC" sh "$ROOT/bootstrap.sh" --dry-run --only core >"$TEST_ROOT/bootstrap2.log" 2>&1 ||
  fail "bootstrap fast-forward failed"
pass "bootstrap clones and fast-forwards a checkout"

printf '\n%d test group(s) passed\n' "$PASS"
