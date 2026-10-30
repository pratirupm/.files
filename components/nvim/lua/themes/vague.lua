-- Vague palette ported into base46.
-- Palette source: https://github.com/vague-theme/vague.nvim
-- The plugin itself is intentionally not loaded; base46 caches load after
-- plugins and would overwrite it.
local M = {}

M.base_30 = {
  white = "#cdcdcd",
  darker_black = "#101011",
  black = "#141415",
  black2 = "#1c1c24",
  one_bg = "#1c1c24",
  one_bg2 = "#252530",
  one_bg3 = "#333738",
  grey = "#606079",
  grey_fg = "#878787",
  grey_fg2 = "#909090",
  light_grey = "#a0a0a0",
  red = "#d8647e",
  baby_pink = "#c48282",
  pink = "#bb9dbd",
  line = "#252530",
  green = "#7fa563",
  vibrant_green = "#8fb573",
  nord_blue = "#6e94b2",
  blue = "#6e94b2",
  yellow = "#f3be7c",
  sun = "#e0a363",
  purple = "#bb9dbd",
  dark_purple = "#a88ca9",
  teal = "#9bb4bc",
  orange = "#c48282",
  cyan = "#aeaed1",
  statusline_bg = "#1c1c24",
  lightbg = "#252530",
  pmenu_bg = "#c3c3d5",
  folder_bg = "#6e94b2",
}

M.base_16 = {
  base00 = "#141415",
  base01 = "#1c1c24",
  base02 = "#252530",
  base03 = "#606079",
  base04 = "#878787",
  base05 = "#cdcdcd",
  base06 = "#c3c3d5",
  base07 = "#e5e5e5",
  base08 = "#d8647e",
  base09 = "#e8b589",
  base0A = "#f3be7c",
  base0B = "#7fa563",
  base0C = "#b4d4cf",
  base0D = "#6e94b2",
  base0E = "#bb9dbd",
  base0F = "#c48282",
}

M.polish_hl = {
  treesitter = {
    ["@keyword.import"] = { fg = M.base_30.purple },
    ["@uri"] = { fg = M.base_30.blue },
    ["@variable.member.key"] = { fg = M.base_30.white },
    ["@punctuation.bracket"] = { fg = M.base_30.pmenu_bg },
  },
  syntax = {
    Number = { fg = M.base_30.nord_blue },
  },
}

M.type = "dark"

M = require("base46").override_theme(M, "vague")

return M
