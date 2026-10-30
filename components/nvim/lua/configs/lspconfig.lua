require("nvchad.configs.lspconfig").defaults()

-- Diagnostics are rendered on the right side of the status column, so remove
-- their sign-column copies to avoid showing them on the left as well.
local diagnostic_signs = vim.diagnostic.config().signs
if type(diagnostic_signs) == "table" and type(diagnostic_signs.text) == "table" then
  require("configs.statuscolumn").set_diagnostic_text(diagnostic_signs.text)
end
vim.diagnostic.config { signs = false }

local servers = { "html", "cssls", "gopls", "golangci_lint_ls" }
vim.lsp.enable(servers)

-- Keep the built-in LSP keys (grn/gra/grr/grt) and drop NvChad's extra
-- buffer-local leader maps. This autocmd is registered after NvChad's
-- defaults(), so it removes the maps that on_attach just created.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    for _, lhs in ipairs {
      "<leader>ra",
      "<leader>D",
      "<leader>wa",
      "<leader>wr",
      "<leader>wl",
    } do
      pcall(vim.keymap.del, "n", lhs, { buffer = args.buf })
    end
  end,
})

-- On a fresh machine a buffer can be opened before Mason has installed its
-- server. Re-enable the configs after Mason finishes so those buffers attach.
vim.api.nvim_create_autocmd("User", {
  pattern = "MasonToolsUpdateCompleted",
  callback = function()
    vim.schedule(function()
      pcall(vim.lsp.enable, servers)
    end)
  end,
})

-- read :h vim.lsp.config for changing options of lsp servers
