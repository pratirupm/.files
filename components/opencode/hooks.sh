# shellcheck shell=bash
# opencode component hooks. Auth, sessions, service.json, and skills under
# ~/.config/opencode are user data and are never managed here.

component_install() {
  # dry-run must not install plugin deps or download the browser
  if $DRY_RUN; then
    return 0
  fi
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun is not on PATH; the Playwright/Svelte MCP commands need bunx"
  else
    local plugin_dir="$DOTFILES/components/opencode/plugins/force-background"
    if [[ -f "$plugin_dir/package.json" && ! -d "$plugin_dir/node_modules/@opencode/plugin" ]]; then
      if ! (cd "$plugin_dir" && bun install --frozen-lockfile); then
        warn "failed to install the force-background plugin dependencies"
      fi
    fi
    # @playwright/mcp@0.0.84 uses chromium-1252. Install it once, but never in
    # a throwaway HOME (hermetic tests must not download the browser).
    local chrome="$HOME/.cache/ms-playwright/chromium-1252/chrome-linux64/chrome"
    if [[ $HOME != /tmp/* && $HOME != /var/tmp/* && ! -f $chrome ]]; then
      info "installing Chromium 1252 for the Playwright MCP server"
      if ! bunx -y playwright@1.65.0-alpha-2026-10-30 install chromium; then
        warn "failed to install Chromium 1252; run: bunx -y playwright@1.65.0-alpha-2026-10-30 install chromium"
      fi
    fi
  fi
}

component_update() {
  component_install
}

component_uninstall() {
  :
}

component_doctor() {
  local failures=0 config="$HOME/.config/opencode/opencode.json" agent
  local plugin_dir="$DOTFILES/components/opencode/plugins/force-background"
  local -a agents=(
    "agents/planner.md"
    "agents/builder.md"
    "agents/mechanical.md"
    "agents/scout.md"
    "agents/worker.md"
  )
  if ! command -v opencode >/dev/null 2>&1; then
    error "opencode is not on PATH"
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
    config.get("default_agent") == "builder"
    and plan.get("hidden") is True
    and build.get("hidden") is True
    and loads_plugin
)
sys.exit(0 if ok else 1)
'; then
      error "opencode config must default to builder, hide plan and build, and load the force-background plugin: $config"
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
  config.default_agent !== "builder" ||
  plan.hidden !== true ||
  build.hidden !== true ||
  !loadsPlugin
) {
  process.exit(1);
}
'; then
      error "opencode config must default to builder, hide plan and build, and load the force-background plugin: $config"
      failures=$((failures + 1))
    fi
  fi
  if [[ ! -f "$HOME/.config/opencode/AGENTS.md" ]]; then
    error "opencode AGENTS.md is missing"
    failures=$((failures + 1))
  fi
  for agent in "${agents[@]}"; do
    if [[ ! -f "$HOME/.config/opencode/$agent" ]]; then
      error "opencode agent definition is missing: $agent"
      failures=$((failures + 1))
    fi
  done
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
    error "bun is not on PATH; bunx MCP servers will not start"
    failures=$((failures + 1))
  fi
  if [[ ! -f "$HOME/.cache/ms-playwright/chromium-1252/chrome-linux64/chrome" ]]; then
    warn "Playwright MCP browser chromium-1252 is missing; run: bunx -y playwright@1.65.0-alpha-2026-10-30 install chromium"
  fi
  return "$failures"
}
