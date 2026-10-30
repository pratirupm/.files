local dap = require "dap"
local dapui = require "dapui"
local map = vim.keymap.set

dapui.setup()
require("dap-go").setup()

dap.listeners.after.event_initialized.dapui_config = function()
  dapui.open()
end

dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end

dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

map("n", "<F5>", dap.continue, { desc = "DAP continue" })
map("n", "<F10>", dap.step_over, { desc = "DAP step over" })
map("n", "<F11>", dap.step_into, { desc = "DAP step into" })
map("n", "<F12>", dap.step_out, { desc = "DAP step out" })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
map("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })
