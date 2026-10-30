return {
  {
    "olexsmir/gopher.nvim",
    ft = "go",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("gopher").setup {}
    end,
  },

  {
    "nvim-neotest/neotest",
    cmd = "Neotest",
    keys = {
      { "<leader>tr", desc = "Run nearest Go test" },
      { "<leader>tf", desc = "Run Go test file" },
      { "<leader>ts", desc = "Toggle test summary" },
      { "<leader>td", desc = "Debug nearest Go test" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "fredrikaverpil/neotest-golang",
      "leoluz/nvim-dap-go",
    },
    config = function()
      require "configs.neotest"
    end,
  },

  {
    "mfussenegger/nvim-dap",
    cmd = {
      "DapClearBreakpoints",
      "DapContinue",
      "DapDisconnect",
      "DapEval",
      "DapNew",
      "DapPause",
      "DapRestartFrame",
      "DapSetLogLevel",
      "DapShowLog",
      "DapStepInto",
      "DapStepOut",
      "DapStepOver",
      "DapTerminate",
      "DapToggleBreakpoint",
      "DapToggleRepl",
    },
    keys = {
      { "<F5>", desc = "DAP continue" },
      { "<F10>", desc = "DAP step over" },
      { "<F11>", desc = "DAP step into" },
      { "<F12>", desc = "DAP step out" },
      { "<leader>db", desc = "Toggle breakpoint" },
      { "<leader>du", desc = "Toggle DAP UI" },
    },
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "leoluz/nvim-dap-go",
    },
    config = function()
      require "configs.dap"
    end,
  },
}
