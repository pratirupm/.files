-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

require("configs.tabufline").setup()

M.base46 = {
  theme = "vague",
}

M.ui = {
  statusline = {
    theme = "vscode_colored",
  },

  tabufline = {
    lazyload = false,
    order = { "tabs" },
    modules = {
      tabs = require("configs.tabufline").tabs,
    },
  },
}

return M
