local api = vim.api

local M = {}

local id_prefix = "mainTerm_"
local warned = {}

local function normalize_cwd()
  return (vim.fn.getcwd(-1):gsub("[/\\]+$", ""))
end

local function term_id(cwd)
  return id_prefix .. vim.fn.sha256(cwd):sub(1, 12)
end

local function term_opts(cwd)
  return {
    pos = "sp",
    id = term_id(cwd),
    size = 0.3,
    cwd = cwd,
    termopen_opts = { cwd = cwd },
  }
end

local function find_entry(id)
  for key, entry in pairs(vim.g.nvchad_terms or {}) do
    if entry.id == id then
      return key, entry
    end
  end
end

local function clear_entry(key)
  if key and vim.g.nvchad_terms then
    vim.g.nvchad_terms[key] = nil
  end
end

-- Replace the terminal buffer instead of closing the last window (E444).
local function fallback_buffer()
  local alternate = vim.fn.bufnr "#"
  if alternate ~= -1 and api.nvim_buf_is_valid(alternate) and vim.bo[alternate].buftype == "" then
    return alternate
  end

  for _, buf in ipairs(api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == "" then
      return buf
    end
  end

  return api.nvim_create_buf(true, false)
end

local function hide_last_window(win)
  api.nvim_win_set_buf(win, fallback_buffer())
end

local function close_window(entry, win)
  entry.win = win
  local tab = api.nvim_win_get_tabpage(win)
  local floating = api.nvim_win_get_config(win).relative ~= ""

  if floating or #api.nvim_tabpage_list_wins(tab) > 1 then
    api.nvim_win_close(win, true)
  else
    hide_last_window(win)
  end
end

local function tabs_for_cwd(cwd)
  local count = 0
  for _, tab in ipairs(api.nvim_list_tabpages()) do
    local tabnr = api.nvim_tabpage_get_number(tab)
    local tab_cwd = vim.fn.getcwd(-1, tabnr):gsub("[/\\]+$", "")
    if tab_cwd == cwd then
      count = count + 1
    end
  end
  return count
end

-- A shell with no child process is idle; a child means a command is running.
-- If neither pgrep nor ps is available, the state is unknown: keep the shell
-- rather than kill it.
local function process_state(entry)
  if not entry or not api.nvim_buf_is_valid(entry.buf) then
    return "idle"
  end

  local job = vim.b[entry.buf].terminal_job_id
  if not job then
    return "idle"
  end

  local pid = vim.fn.jobpid(job)
  if pid <= 0 then
    return "idle"
  end

  if vim.fn.executable "pgrep" == 1 then
    vim.fn.system { "pgrep", "-P", tostring(pid) }
    local code = vim.v.shell_error
    if code == 0 then
      return "running"
    elseif code ~= 1 then
      return "unknown"
    end
  elseif vim.fn.executable "ps" == 1 then
    local out = vim.fn.system { "ps", "-o", "pid=", "--ppid", tostring(pid) }
    if vim.v.shell_error ~= 0 then
      return "unknown"
    end
    if out:gsub("%s+", "") ~= "" then
      return "running"
    end
  else
    return "unknown"
  end

  -- Bash shell builtins such as `read` have no child process. On Linux the
  -- shell's wait channel distinguishes an idle prompt (poll/select) from a
  -- builtin waiting for input, so avoid killing that shell.
  if vim.fn.has "linux" == 1 and vim.fn.executable "ps" == 1 then
    local out = vim.fn.system { "ps", "-o", "wchan=", "-p", tostring(pid) }
    if vim.v.shell_error ~= 0 then
      return "unknown"
    end
    local wchan = out:gsub("%s+", "")
    if wchan:find("poll", 1, true) or wchan:find("select", 1, true) or wchan:find("epoll", 1, true) then
      return "idle"
    end
    return "running"
  end

  return "unknown"
end

function M.toggle()
  local cwd = normalize_cwd()
  local id = term_id(cwd)
  local key, entry = find_entry(id)

  if entry and not api.nvim_buf_is_valid(entry.buf) then
    clear_entry(key)
    entry = nil
  end

  if entry then
    local win = vim.fn.bufwinid(entry.buf)
    if win ~= -1 then
      close_window(entry, win)
      return
    end
  end

  require("nvchad.term").toggle(term_opts(cwd))
end

-- Called by projects.close_tab before closing a tab. Refuse to close the last
-- tab for a project while its terminal still has a running process.
function M.guard_close()
  local cwd = normalize_cwd()
  if tabs_for_cwd(cwd) > 1 then
    return true
  end

  local _, entry = find_entry(term_id(cwd))
  if not entry or process_state(entry) ~= "running" then
    return true
  end

  local current_tab = api.nvim_get_current_tabpage()
  for _, win in ipairs(vim.fn.win_findbuf(entry.buf)) do
    if api.nvim_win_get_tabpage(win) ~= current_tab then
      return true
    end
  end

  local win = vim.fn.bufwinid(entry.buf)
  if win == -1 then
    require("nvchad.term").toggle(term_opts(cwd))
    win = vim.fn.bufwinid(entry.buf)
  end

  if win ~= -1 then
    api.nvim_set_current_win(win)
  end

  vim.notify(
    "Stop the running process in " .. vim.fn.fnamemodify(cwd, ":t") .. " before closing the project tab",
    vim.log.levels.WARN
  )
  return false
end

local function cleanup_terminals()
  local stale = {}
  for key, entry in pairs(vim.g.nvchad_terms or {}) do
    if type(entry.id) == "string" and entry.id:find("^" .. id_prefix) then
      local cwd = entry.cwd
      if cwd and tabs_for_cwd(cwd) == 0 and #vim.fn.win_findbuf(entry.buf) == 0 then
        local state = process_state(entry)
        if state == "idle" then
          stale[#stale + 1] = { key = key, entry = entry }
        elseif not warned[entry.buf] then
          warned[entry.buf] = true
          local message = state == "running" and "is still running" or "state is unknown; kept hidden"
          vim.notify("Terminal for " .. vim.fn.fnamemodify(cwd, ":t") .. " " .. message, vim.log.levels.WARN)
        end
      end
    end
  end

  for _, item in ipairs(stale) do
    if api.nvim_buf_is_valid(item.entry.buf) then
      api.nvim_buf_delete(item.entry.buf, { force = true })
    end
    clear_entry(item.key)
  end
end

function M.setup()
  local map = vim.keymap.set
  local del = vim.keymap.del

  pcall(del, "n", "<leader>h")
  pcall(del, "n", "<leader>v")
  pcall(del, { "n", "t" }, "<A-h>")
  pcall(del, { "n", "t" }, "<A-v>")
  pcall(del, { "n", "t" }, "<A-i>")

  map("n", "<leader>tt", M.toggle, { desc = "Toggle terminal" })
  map("t", "<C-t>", M.toggle, { desc = "Toggle terminal" })

  api.nvim_create_autocmd("TabClosed", {
    group = api.nvim_create_augroup("UserProjectTerminals", { clear = true }),
    callback = function()
      vim.schedule(cleanup_terminals)
    end,
  })
end

return M
