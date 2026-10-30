require "nvchad.options"

-- Indentation: four columns everywhere. Spaces remain the default, but
-- filetypes such as Go and Make can still opt into hard tabs.
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.shiftround = true

-- Display and editing.
vim.opt.colorcolumn = "80"
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorlineopt = "both"
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.fillchars:append {
  fold = " ",
  foldopen = "",
  foldclose = "",
  foldsep = " ",
}
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.smoothscroll = true

require("configs.statuscolumn").setup()
require("configs.projects").setup()
require("configs.bufferbar").setup()

vim.opt.showtabline = 2

-- Command-line and completion behavior.
vim.opt.inccommand = "split"
vim.opt.wildignorecase = true
vim.opt.wildmode = "longest:full,full"
vim.opt.pumheight = 12
vim.opt.shortmess:append "c"
vim.opt.jumpoptions:append "view"

-- Scrolling, windows, and files.
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.confirm = true
vim.opt.winborder = "rounded"
vim.opt.swapfile = false
vim.opt.undofile = true
