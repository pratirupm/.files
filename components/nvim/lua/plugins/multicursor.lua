return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
      { "<leader>mj", mode = { "n", "x" }, desc = "multicursor add cursor below" },
      { "<leader>mk", mode = { "n", "x" }, desc = "multicursor add cursor above" },
      { "<leader>mn", mode = { "n", "x" }, desc = "multicursor add next match" },
      { "<leader>ma", mode = { "n", "x" }, desc = "multicursor add all matches" },
      { "<leader>mc", mode = { "n", "x" }, desc = "multicursor clear cursors" },
    },
    config = function()
      require "configs.multicursor"
    end,
  },
}
