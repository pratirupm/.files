return {
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "Open lazygit" },
      { "<leader>gf", "<cmd>LazyGitCurrentFile<cr>", desc = "Open lazygit for current file" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
      { "<leader>dd", "<cmd>Trouble diagnostics toggle<cr>", desc = "Toggle diagnostics panel" },
      { "<leader>dq", "<cmd>Trouble qflist toggle<cr>", desc = "Toggle quickfix panel" },
    },
    opts = {
      open_no_results = true,
    },
  },

  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    keys = {
      {
        "<leader>sr",
        function()
          require("grug-far").open()
        end,
        desc = "Search and replace across project",
      },
    },
    opts = {},
  },

  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
    -- Use <C-\><C-n> instead of <Esc> so multicursor's active <Esc> layer
    -- does not intercept the change/delete aliases.
    keys = {
      { "ms", "<Plug>(nvim-surround-visual)", mode = "x", remap = true, desc = "Add surrounding" },
      { "mr", "<C-\\><C-n><Plug>(nvim-surround-change)", mode = "x", remap = true, desc = "Change surrounding" },
      { "md", "<C-\\><C-n><Plug>(nvim-surround-delete)", mode = "x", remap = true, desc = "Delete surrounding" },
    },
  },
}
