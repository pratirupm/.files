local M = {}

local severity = vim.diagnostic.severity

local diagnostic_hl = {
  [severity.ERROR] = "DiagnosticSignError",
  [severity.WARN] = "DiagnosticSignWarn",
  [severity.INFO] = "DiagnosticSignInfo",
  [severity.HINT] = "DiagnosticSignHint",
}

M.diagnostic_text = {
  [severity.ERROR] = "󰅙",
  [severity.WARN] = "",
  [severity.INFO] = "󰋼",
  [severity.HINT] = "󰌵",
}

local diagnostic_cache = {}

local function diagnostics_by_line(buf)
  local cached = diagnostic_cache[buf]
  if cached then
    return cached
  end

  local by_line = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
    local lnum = diagnostic.lnum + 1
    local current = by_line[lnum]
    if not current or (diagnostic.severity or severity.HINT) < (current.severity or severity.HINT) then
      by_line[lnum] = diagnostic
    end
  end

  diagnostic_cache[buf] = by_line
  return by_line
end

function M.set_diagnostic_text(text)
  if type(text) == "table" then
    M.diagnostic_text = text
  end
end

local function fillchar(name, fallback)
  return vim.opt.fillchars:get()[name] or fallback
end

-- Use the GitSigns highlight for a fold marker when the line also has a git
-- change. The glyph still shows the fold state; the color carries the git
-- state, so both fit in one column.
local function git_highlight(buf, lnum)
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    -1,
    { lnum - 1, 0 },
    { lnum - 1, -1 },
    { details = true, type = "sign" }
  )

  for _, mark in ipairs(marks) do
    local hl = mark[4].sign_hl_group
    if hl and hl:find("GitSign", 1, true) then
      return hl
    end
  end
end

-- Return a formatted fold marker for fold-start lines, or nil for other
-- lines. Closed folds take priority; open fold starts also show the marker.
function M.marker(buf)
  local lnum = vim.v.lnum
  local closed = vim.fn.foldclosed(lnum) ~= -1
  local level = vim.fn.foldlevel(lnum)

  if not closed and (level == 0 or level <= vim.fn.foldlevel(lnum - 1)) then
    return nil
  end

  local glyph = closed and fillchar("foldclose", "") or fillchar("foldopen", "")
  local hl = git_highlight(buf, lnum) or "FoldColumn"
  return ("%%#%s#%s %%*"):format(hl, glyph)
end

-- Return the highest-severity diagnostic marker for a line, or nil.
function M.diagnostic(buf)
  local diagnostic = diagnostics_by_line(buf)[vim.v.lnum]
  if not diagnostic then
    return nil
  end

  local level = diagnostic.severity or severity.ERROR
  local text = M.diagnostic_text[level] or "●"
  local hl = diagnostic_hl[level] or "DiagnosticSignError"
  return ("%%#%s#%s%%*"):format(hl, text)
end

-- Keep the normal columns for file windows, but leave terminal, help, and
-- tree-like windows alone.
function M.get()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local buftype = vim.bo[buf].buftype

  -- nvim-tree draws its diagnostics as signs; keep its sign column visible.
  if vim.bo[buf].filetype == "NvimTree" then
    return "%s"
  end

  if buftype ~= "" and buftype ~= "quickfix" then
    return ""
  end

  local marker = M.marker(buf)
  local diagnostic = M.diagnostic(buf) or " "
  local suffix = diagnostic .. " "

  if marker then
    return marker .. "%l " .. suffix
  end

  return "%s%l " .. suffix
end

function M.setup()
  vim.o.statuscolumn = "%!v:lua.require'configs.statuscolumn'.get()"
  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufDelete" }, {
    group = vim.api.nvim_create_augroup("UserStatusColumn", { clear = true }),
    callback = function(args)
      if args.event == "BufDelete" then
        diagnostic_cache[args.buf] = nil
      else
        diagnostic_cache = {}
      end
    end,
  })
end

return M
