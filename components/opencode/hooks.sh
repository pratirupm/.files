# shellcheck shell=bash
# opencode component hooks. Auth, sessions, service.json, and skills under
# ~/.config/opencode are user data and are never managed here.

OPENCODE_BIN="$HOME/.opencode/bin/opencode"
OPENCODE_INSTALL_URL=${DOTFILES_OPENCODE_INSTALL_URL:-https://opencode.ai/v2/install}
PLAYWRIGHT_MCP_META_URL=${DOTFILES_PLAYWRIGHT_MCP_META_URL:-https://registry.npmjs.org/@playwright%2fmcp/latest}

opencode_remove_legacy() {
  local rel target
  for rel in \
    AGENTS.md \
    agents/planner.md \
    agents/builder.md \
    agents/mechanical.md \
    agents/scout.md \
    agents/worker.md; do
    target="$HOME/.config/opencode/$rel"
    [[ -L $target ]] || continue
    case "$(readlink -- "$target")" in
      "$DOTFILES/components/opencode/"*) run rm -f -- "$target" ;;
    esac
  done
  if [[ -d "$HOME/.config/opencode/agents" ]]; then
    run rmdir -- "$HOME/.config/opencode/agents" 2>/dev/null || true
  fi
  # The browser toggle is gone; clean up its state file.
  run rm -f -- "${STATE_DIR:-$HOME/.local/state/dotfiles}/opencode-browser"
}

opencode_install_binary() {
  if [[ ${DOTFILES_SKIP_OPENCODE_INSTALL:-0} == 1 ]]; then
    debug "skipping the opencode installer"
    return 0
  fi
  if $DRY_RUN; then
    info "[dry-run] install opencode with the official v2 installer"
    return 0
  fi

  local installer=${DOTFILES_OPENCODE_INSTALLER:-} tmp=""
  if [[ -z $installer ]]; then
    tmp=$(mktemp "${TMPDIR:-/tmp}/opencode-install.XXXXXX")
    installer=$tmp
    if ! http_get "$OPENCODE_INSTALL_URL" "$installer"; then
      rm -f -- "$tmp"
      die "failed to download the opencode installer"
    fi
  fi

  info "install opencode with the official installer"
  if ! bash "$installer" --no-modify-path; then
    if [[ -n $tmp ]]; then
      rm -f -- "$tmp"
    fi
    die "opencode installer failed"
  fi
  if [[ -n $tmp ]]; then
    rm -f -- "$tmp"
  fi
  touch "${STATE_DIR:-$HOME/.local/state/dotfiles}/opencode-installed"
}

opencode_mcp_playwright_version() {
  local meta version
  if [[ -n ${DOTFILES_PLAYWRIGHT_VERSION:-} ]]; then
    printf '%s\n' "$DOTFILES_PLAYWRIGHT_VERSION"
    return 0
  fi

  meta=$(mktemp "${TMPDIR:-/tmp}/opencode-mcp.XXXXXX")
  if ! http_get "$PLAYWRIGHT_MCP_META_URL" "$meta"; then
    rm -f -- "$meta"
    return 1
  fi
  version=$(sed -n 's/.*"playwright": *"\([^"]*\)".*/\1/p' "$meta" | head -n 1 || true)
  rm -f -- "$meta"
  [[ -n $version ]] || return 1
  printf '%s\n' "$version"
}

opencode_install_playwright() {
  local version root log browser
  if [[ ${DOTFILES_SKIP_BROWSER:-0} == 1 ]]; then
    debug "skipping the Playwright browser install"
    return 0
  fi
  if $DRY_RUN; then
    info "[dry-run] install Playwright Chromium for the MCP server"
    return 0
  fi
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun is not on PATH; the Playwright MCP browser cannot be installed"
    return 0
  fi
  if ! version=$(opencode_mcp_playwright_version); then
    warn "could not resolve the Playwright version for @playwright/mcp; retry: dotfiles install --only opencode"
    return 0
  fi

  root=$(opencode_browser_root)
  log="${STATE_DIR:-$HOME/.local/state/dotfiles}/logs/opencode-playwright.log"
  mkdir -p "$(dirname "$log")"
  {
    printf '== %s\n' "$(date -Is)"
    printf 'bun=%s\n' "$(command -v bun)"
    printf 'root=%s\n' "$root"
    printf 'version=%s\n' "$version"
  } >"$log"

  info "install Playwright Chromium for @playwright/mcp (playwright $version)"
  if ! env -u PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD \
    bun x -y "playwright@$version" install chromium 2>&1 | tee -a "$log"; then
    warn "failed to install Playwright Chromium; see $log"
    return 0
  fi

  browser=$(opencode_browser_binary)
  if [[ -n $browser ]]; then
    return 0
  fi

  info "Playwright reported success but no browser was found; retrying with --force"
  if ! env -u PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD \
    bun x -y "playwright@$version" install --force chromium 2>&1 | tee -a "$log"; then
    warn "failed to install Playwright Chromium; see $log"
    return 0
  fi
  if [[ -z $(opencode_browser_binary) ]]; then
    warn "Playwright Chromium is still missing from $root; see $log"
  fi
}

opencode_browser_root() {
  if [[ -n ${PLAYWRIGHT_BROWSERS_PATH:-} ]]; then
    if [[ $PLAYWRIGHT_BROWSERS_PATH == 0 ]]; then
      printf '%s\n' "$HOME/.bun/install/cache"
    else
      printf '%s\n' "$PLAYWRIGHT_BROWSERS_PATH"
    fi
    return 0
  fi
  printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/ms-playwright"
}

opencode_browser_binary() {
  local root
  root=$(opencode_browser_root)
  find -H "$root" -maxdepth 8 -type f \
    \( -name chrome -o -name headless_shell -o -name chrome-headless-shell \) \
    -print -quit 2>/dev/null || true
}

component_install() {
  opencode_remove_legacy
  if [[ ! -x $OPENCODE_BIN ]]; then
    opencode_install_binary
  fi
  # dry-run must not install plugin deps; report the browser step and stop.
  if $DRY_RUN; then
    opencode_install_playwright
    return 0
  fi

  if ! command -v bun >/dev/null 2>&1; then
    warn "bun is not on PATH; the force-background plugin and Playwright MCP browser need it"
    return 0
  fi

  local plugin_dir="$DOTFILES/components/opencode/plugins/force-background"
  if [[ -f "$plugin_dir/package.json" && ! -d "$plugin_dir/node_modules/@opencode/plugin" ]]; then
    if ! (cd "$plugin_dir" && bun install --frozen-lockfile); then
      warn "failed to install the force-background plugin dependencies"
    fi
  fi

  opencode_install_playwright
}

component_update() {
  component_install
}

component_uninstall() {
  local state_dir=${STATE_DIR:-$HOME/.local/state/dotfiles}
  if ${PURGE:-false} && [[ -f "$state_dir/opencode-installed" ]]; then
    info "remove opencode installed by the official installer"
    run rm -f -- "$HOME/.opencode/bin/opencode" "$HOME/.opencode/bin/opencode2"
    run rmdir -- "$HOME/.opencode/bin" "$HOME/.opencode" 2>/dev/null || true
    run rm -f -- "$state_dir/opencode-installed"
  fi
}

component_doctor() {
  local failures=0 config="$HOME/.config/opencode/opencode.json" browser
  local plugin_dir="$DOTFILES/components/opencode/plugins/force-background"
  if ! command -v opencode >/dev/null 2>&1; then
    error "opencode is not on PATH"
    failures=$((failures + 1))
  fi
  if [[ ! -x $OPENCODE_BIN ]]; then
    error "opencode is not installed at $OPENCODE_BIN; run: dotfiles install --only opencode"
    failures=$((failures + 1))
  fi
  if [[ ! -f $config ]]; then
    error "opencode config is missing: $config"
    failures=$((failures + 1))
  elif command -v python3 >/dev/null 2>&1; then
    if ! python3 -m json.tool "$config" >/dev/null; then
      error "opencode config is not valid JSON: $config"
      failures=$((failures + 1))
    elif ! DOTFILES_JSON="$config" python3 -c '
import json, os, sys

with open(os.environ["DOTFILES_JSON"], encoding="utf-8") as handle:
    config = json.load(handle)
agents = config.get("agents") or {}
plan = agents.get("plan") or {}
build = agents.get("build") or {}
plugins = config.get("plugins") or []
loads_plugin = any(
    isinstance(entry, str) and "force-background" in entry
    for entry in plugins
)
ok = (
    config.get("update") == "auto"
    and not config.get("default_agent")
    and plan.get("hidden") is not True
    and build.get("hidden") is not True
    and loads_plugin
)
sys.exit(0 if ok else 1)
'; then
      error "opencode config must keep the default agents, set update=auto, and load the force-background plugin: $config"
      failures=$((failures + 1))
    fi
  elif command -v node >/dev/null 2>&1; then
    if ! DOTFILES_JSON="$config" node -e 'JSON.parse(require("fs").readFileSync(process.env.DOTFILES_JSON, "utf8"))'; then
      error "opencode config is not valid JSON: $config"
      failures=$((failures + 1))
    elif ! DOTFILES_JSON="$config" node -e '
const fs = require("fs");
const config = JSON.parse(fs.readFileSync(process.env.DOTFILES_JSON, "utf8"));
const agents = config.agents || {};
const plan = agents.plan || {};
const build = agents.build || {};
const plugins = config.plugins || [];
const loadsPlugin = plugins.some(
  (entry) => typeof entry === "string" && entry.includes("force-background"),
);
if (
  config.update !== "auto" ||
  config.default_agent ||
  plan.hidden === true ||
  build.hidden === true ||
  !loadsPlugin
) {
  process.exit(1);
}
'; then
      error "opencode config must keep the default agents, set update=auto, and load the force-background plugin: $config"
      failures=$((failures + 1))
    fi
  fi
  if [[ ! -f "$HOME/.config/opencode/themes/vague.json" ]]; then
    error "opencode vague theme is missing"
    failures=$((failures + 1))
  fi
  if [[ ! -f "$plugin_dir/index.ts" ]]; then
    error "force-background plugin is missing index.ts: $plugin_dir"
    failures=$((failures + 1))
  fi
  if [[ ! -f "$plugin_dir/package.json" ]]; then
    error "force-background plugin is missing package.json: $plugin_dir"
    failures=$((failures + 1))
  fi
  if [[ ! -d "$plugin_dir/node_modules/@opencode/plugin" ]]; then
    error "force-background plugin dependencies are missing; run bun install in $plugin_dir"
    failures=$((failures + 1))
  fi
  if ! command -v bun >/dev/null 2>&1; then
    error "bun is not on PATH; the Bun MCP servers and Playwright browser need it"
    failures=$((failures + 1))
  fi
  if [[ ${DOTFILES_SKIP_BROWSER:-0} != 1 ]]; then
    local browser_root
    browser_root=$(opencode_browser_root)
    browser=$(opencode_browser_binary)
    if [[ -z $browser ]]; then
      error "Playwright Chromium is missing from $browser_root; run: dotfiles install --only opencode"
      failures=$((failures + 1))
    fi
  fi
  return "$failures"
}
