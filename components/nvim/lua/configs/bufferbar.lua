local M = {}
local api = vim.api

function M.render()
  local win = vim.g.statusline_winid
  if not win or win == 0 then
    win = api.nvim_get_current_win()
  end
  if not api.nvim_win_is_valid(win) then
    return ""
  end

  local buf = api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype == "NvimTree" then
    return ""
  end
  if not vim.t.bufs or #vim.t.bufs == 0 then
    return ""
  end

  -- winbar can be evaluated while NvChad's nvconfig module is still loading.
  -- Requiring tabufline.utils then creates a circular require and poisons the
  -- module cache, so defer rendering until nvconfig is available.
  if type(package.loaded["nvconfig"]) ~= "table" then
    return ""
  end
  local ok, utils = pcall(require, "nvchad.tabufline.utils")
  if not ok then
    return ""
  end
  return api.nvim_win_call(win, function()
    local parts = {}
    for i, bufnr in ipairs(vim.t.bufs) do
      if api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
        parts[#parts + 1] = utils.style_buf(bufnr, i, 18)
      end
    end
    return table.concat(parts) .. "%="
  end)
end

function M.setup()
  vim.o.winbar = "%!v:lua.require'configs.bufferbar'.render()"
end

return M
