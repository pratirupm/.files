local opts = require "nvchad.configs.nvimtree"

opts.view.side = "right"
opts.actions = vim.tbl_deep_extend("force", opts.actions or {}, {
  open_file = { quit_on_open = true },
})
opts.diagnostics = {
  enable = true,
  show_on_dirs = true,
  show_on_open_dirs = true,
  debounce_delay = 100,
  icons = {
    hint = "󰌵",
    info = "󰋼",
    warning = "",
    error = "󰅙",
  },
}

-- nvim-tree only updates its severity cache on DiagnosticChanged, so force a
-- refresh when the tree opens and after a write.
local group = vim.api.nvim_create_augroup("UserNvimTreeDiagnostics", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "NvimTree",
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        require("nvim-tree.diagnostics").update_lsp { buf = buf, data = { diagnostics = {} } }
      end
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = group,
  callback = function(args)
    if package.loaded["nvim-tree.diagnostics"] then
      require("nvim-tree.diagnostics").update_lsp { buf = args.buf, data = { diagnostics = {} } }
    end
  end,
})

return opts
