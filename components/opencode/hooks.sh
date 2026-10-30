# shellcheck shell=bash
# opencode component hooks. Auth, sessions, service.json, and skills under
# ~/.config/opencode are user data and are never managed here.

component_install() {
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun is not on PATH; the Playwright/Svelte MCP commands need bunx"
  fi
}

component_update() {
  component_install
}

component_uninstall() {
  :
}

component_doctor() {
  local failures=0 config="$HOME/.config/opencode/opencode.json"
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
    fi
  elif command -v node >/dev/null 2>&1; then
    if ! DOTFILES_JSON="$config" node -e 'JSON.parse(require("fs").readFileSync(process.env.DOTFILES_JSON, "utf8"))'; then
      error "opencode config is not valid JSON: $config"
      failures=$((failures + 1))
    fi
  fi
  if [[ ! -f "$HOME/.config/opencode/themes/vague.json" ]]; then
    error "opencode vague theme is missing"
    failures=$((failures + 1))
  fi
  if ! command -v bun >/dev/null 2>&1; then
    error "bun is not on PATH; bunx MCP servers will not start"
    failures=$((failures + 1))
  fi
  return "$failures"
}
