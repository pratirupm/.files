require "nvchad.mappings"

local map = vim.keymap.set
local del = vim.keymap.del

-- Drop rarely used defaults so the leader menu stays small.
for _, lhs in ipairs {
  "<leader>n",
  "<leader>rn",
  "<leader>ch",
  "<leader>ds",
  "<leader>fh",
  "<leader>fz",
  "<leader>gt",
  "<leader>cm",
  "<leader>pt",
  "<leader>th",
  "<leader>wk",
  "<leader>wK",
} do
  pcall(del, "n", lhs)
end

-- Drop built-in list-navigation motions; the Ex commands remain available.
for _, lhs in ipairs {
  "]b",
  "[b",
  "]l",
  "[l",
  "]q",
  "[q",
  "]A",
  "[A",
  "]B",
  "[B",
  "]L",
  "[L",
  "]Q",
  "[Q",
  "]T",
  "[T",
  "]D",
  "[D",
  "]<C-L>",
  "[<C-L>",
  "]<C-Q>",
  "[<C-Q>",
  "]<C-T>",
  "[<C-T>",
} do
  pcall(del, "n", lhs)
end

pcall(del, "n", "<C-n>")

-- <leader>e was open-only; make it a real tree toggle.
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })

-- Project tabs.
map("n", "<leader>pa", function()
  require("configs.projects").add_prompt()
end, { desc = "Add project" })

map("n", "<leader>po", function()
  require("configs.projects").pick()
end, { desc = "Open project" })

map("n", "<leader>pc", function()
  require("configs.projects").close_tab()
end, { desc = "Close tab" })

map("n", "<C-]>", function()
  vim.cmd "tabprevious"
  vim.cmd "nohlsearch"
end, { desc = "Previous tab" })

map("n", "<C-\\>", "<cmd>tabnext<CR>", { desc = "Next tab" })

-- <leader>ma previously opened Telescope marks; use it to load multicursor
-- and add all matches. The plugin's config replaces this stub once loaded.
if not package.loaded["multicursor-nvim"] then
  map({ "n", "x" }, "<leader>ma", function()
    require("lazy").load { plugins = { "multicursor.nvim" } }
    require("multicursor-nvim").matchAllAddCursors()
  end, { desc = "multicursor add all matches" })
end

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Redo; visual U still uppercases the selection.
map("n", "U", "<C-r>", { desc = "Redo" })

-- Helix-style word selection for the visual surround aliases in workflow.lua.
map("n", "miw", "viw", { desc = "Select inside word" })
map("n", "maw", "vaw", { desc = "Select around word" })
map("n", "miW", "viW", { desc = "Select inside WORD" })
map("n", "maW", "vaW", { desc = "Select around WORD" })

-- Treesitter selection. From normal mode <C-Space> starts a selection;
-- in visual mode it expands, and <BS> contracts.
local function select_node(target)
  local count = vim.v.count1
  if vim.treesitter.get_parser(nil, nil, { error = false }) then
    vim.treesitter.select(target, count)
  else
    pcall(vim.lsp.buf.selection_range, target == "parent" and count or -count)
  end
end

map({ "n", "x" }, "<C-Space>", function()
  select_node "parent"
end, { desc = "Expand selection" })

map("x", "<BS>", function()
  select_node "child"
end, { desc = "Contract selection" })

-- Move the current line, or the visual selection, up/down.
local function move_line(delta)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if (delta > 0 and lnum == vim.api.nvim_buf_line_count(0)) or (delta < 0 and lnum == 1) then
    return
  end

  vim.cmd(("silent! m %s"):format(delta > 0 and ".+1" or ".-2"))
  vim.cmd "normal! =="
end

local function select_lines(start, count)
  vim.api.nvim_win_set_cursor(0, { start, 0 })
  if count > 1 then
    vim.cmd(("normal! V%dj"):format(count - 1))
  else
    vim.cmd "normal! V"
  end
end

local function move_selection(delta)
  -- Leave visual mode so '< and '> are set.
  vim.cmd "normal! \27"

  local first = vim.fn.line "'<"
  local last = vim.fn.line "'>"
  if first > last then
    first, last = last, first
  end

  local count = last - first + 1
  if (delta > 0 and last == vim.api.nvim_buf_line_count(0)) or (delta < 0 and first == 1) then
    select_lines(first, count)
    return
  end

  local target = delta > 0 and last + 1 or first - 2
  vim.cmd(("silent! %d,%dm %d"):format(first, last, target))

  local new_first = target > last and target - count + 1 or target + 1
  select_lines(math.max(new_first, 1), count)
  vim.cmd "normal! =gv"
end

map("n", "<A-j>", function()
  move_line(1)
end, { desc = "Move line down" })

map("n", "<A-k>", function()
  move_line(-1)
end, { desc = "Move line up" })

map("x", "<A-j>", function()
  move_selection(1)
end, { desc = "Move selection down" })

map("x", "<A-k>", function()
  move_selection(-1)
end, { desc = "Move selection up" })

-- One persistent bottom terminal; replaces NvChad's split/spawn shortcuts.
require("configs.terminal").setup()
