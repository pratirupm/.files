local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "goimports", "golines" },
  },

  formatters = {
    golines = {
      args = { "--max-len=80", "--base-formatter=gofmt" },
    },
  },

  format_on_save = function(bufnr)
    if vim.bo[bufnr].filetype ~= "go" then
      return nil
    end

    return {
      timeout_ms = 5000,
      lsp_format = "never",
    }
  end,
}

return options
