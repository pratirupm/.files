return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    cmd = {
      "MasonToolsClean",
      "MasonToolsInstall",
      "MasonToolsInstallSync",
      "MasonToolsUpdate",
      "MasonToolsUpdateSync",
    },
    opts = {
      ensure_installed = {
        -- Existing NvChad language servers, so a fresh clone works.
        "lua-language-server",
        "html-lsp",
        "css-lsp",

        -- Go language servers and tools.
        "gopls",
        "delve",
        "goimports",
        "golines",
        "golangci-lint",
        "golangci-lint-langserver",
        "gotestsum",
        "gomodifytags",
        "gotests",
        "impl",
        "iferr",

        -- Formatters and Tree-sitter parser builds.
        "stylua",
        "tree-sitter-cli",
      },
      auto_update = false,
      run_on_start = true,
      start_delay = 3000,
    },
    config = function(_, opts)
      require("mason-tool-installer").setup(opts)
    end,
  },
}
