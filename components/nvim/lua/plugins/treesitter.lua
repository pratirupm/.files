return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- NvChad's default build runs `TSInstallAll`; parsers are installed on demand instead.
    build = false,
    init = function()
      require "configs.treesitter"
    end,
  },
}
