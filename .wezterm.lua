local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.color_scheme = 'Gruvbox dark, hard (base16)'

config.font = wezterm.font {
  family = '0xProto Nerd Font'
}
config.harfbuzz_features = { 'ss01' }
config.tab_bar_at_bottom = true
config.use_fancy_tab_bar = false
config.colors = {
  tab_bar         = {
    background = '#1d2021',
    active_tab = {
      bg_color = '#fe8019',
      fg_color = '#1d2021',
    },
  },
}
wezterm.on("update-right-status", function(window, _)
  local background = "#1d2021"
  local foreground = "#fbf1c7"

  if window:leader_is_active() then
    background = "#fe8019"
    foreground = "#1d2021"
  end
  window:set_left_status(wezterm.format {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = " " .. utf8.char(0xf140c) .. " " },
  })
end)
config.window_close_confirmation = 'NeverPrompt'
config.leader = { key = "q", mods = "ALT", timeout_milliseconds = 2000 }
config.keys = {
  {
    key = 'w',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentTab { confirm = false },
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  {
    key = 'n',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = '\\',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = false },
  },
  {
    key = 'h',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection "Left",
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection "Down",
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection "Up",
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection "Right",
  },
  {
    key = 'LeftArrow',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { "Left", 5 },
  },
  {
    key = 'RightArrow',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { "Right", 5 },
  },
  {
    key = 'UpArrow',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { "Up", 5 },
  },
  {
    key = 'DownArrow',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { "Down", 5 },
  },
}
for i = 0, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "LEADER",
    action = wezterm.action.ActivateTab(i)
  })
end
return config
