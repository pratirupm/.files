local M = {}

local data_file = vim.fn.stdpath "data" .. "/projects.json"

local function normalize(path)
  path = vim.fn.expand(path)
  path = vim.fn.fnamemodify(path, ":p")
  return (path:gsub("[/\\]+$", ""))
end

local function load()
  local ok, lines = pcall(vim.fn.readfile, data_file)
  if not ok or #lines == 0 then
    return {}
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(decoded) ~= "table" then
    return {}
  end

  local projects = {}
  for _, path in ipairs(decoded) do
    if type(path) == "string" and vim.fn.isdirectory(path) == 1 then
      projects[#projects + 1] = path
    end
  end
  table.sort(projects)
  return projects
end

local function save(projects)
  vim.fn.mkdir(vim.fn.stdpath "data", "p")
  local ok = vim.fn.writefile({ vim.json.encode(projects) }, data_file)
  if ok ~= 0 then
    vim.notify("Could not save projects to " .. data_file, vim.log.levels.ERROR)
  end
end

function M.add(path)
  path = normalize(path or vim.fn.getcwd())
  if vim.fn.isdirectory(path) ~= 1 then
    vim.notify("Not a directory: " .. path, vim.log.levels.ERROR)
    return
  end

  local projects = load()
  if vim.tbl_contains(projects, path) then
    vim.notify("Project already added: " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
    return
  end

  projects[#projects + 1] = path
  table.sort(projects)
  save(projects)
  vim.notify("Added project: " .. vim.fn.fnamemodify(path, ":~"))
end

function M.add_prompt()
  vim.ui.input({
    prompt = "Project path: ",
    default = vim.fn.getcwd() .. "/",
    completion = "dir",
  }, function(input)
    if input and input ~= "" then
      M.add(input)
    end
  end)
end

function M.remove(path)
  local projects = load()
  local filtered = {}
  for _, project in ipairs(projects) do
    if project ~= path then
      filtered[#filtered + 1] = project
    end
  end
  save(filtered)
  vim.notify("Removed project: " .. vim.fn.fnamemodify(path, ":~"))
end

function M.close_tab()
  if vim.fn.tabpagenr "$" == 1 then
    vim.notify("Cannot close the last tab", vim.log.levels.WARN)
    return
  end

  local modified = {}
  local seen = {}

  local function add(buf)
    if buf > 0 and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified and not seen[buf] then
      seen[buf] = true
      local name = vim.api.nvim_buf_get_name(buf)
      modified[#modified + 1] = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
    end
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    add(vim.api.nvim_win_get_buf(win))
  end
  for _, buf in ipairs(vim.t.bufs or {}) do
    add(buf)
  end

  if #modified > 0 then
    local choice =
      vim.fn.confirm("Unsaved changes in " .. table.concat(modified, ", ") .. ". Close tab?", "&Close\n&Cancel", 2)
    if choice ~= 1 then
      return
    end
  end

  if not require("configs.terminal").guard_close() then
    return
  end

  vim.cmd "tabclose"
end

local function open(path)
  vim.cmd "tabnew"
  vim.cmd("tcd " .. vim.fn.fnameescape(path))
  require("telescope.builtin").find_files {
    cwd = path,
    prompt_title = "Project: " .. vim.fn.fnamemodify(path, ":t"),
  }
end

function M.pick()
  local projects = load()
  if #projects == 0 then
    vim.notify("No projects. Use <leader>pa to add one.", vim.log.levels.INFO)
    return
  end

  local pickers = require "telescope.pickers"
  local finders = require "telescope.finders"
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  local function remove_selection(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if not selection then
      return
    end
    actions.close(prompt_bufnr)
    M.remove(selection.value)
    vim.schedule(M.pick)
  end

  pickers
    .new({}, {
      prompt_title = "Projects",
      finder = finders.new_table {
        results = projects,
        entry_maker = function(path)
          return {
            value = path,
            display = vim.fn.fnamemodify(path, ":~"),
            ordinal = path,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open(selection.value)
          end
        end)

        map("i", "<C-d>", function()
          remove_selection(prompt_bufnr)
        end)
        map("n", "<C-d>", function()
          remove_selection(prompt_bufnr)
        end)
        return true
      end,
    })
    :find()
end

function M.setup()
  vim.api.nvim_create_user_command("ProjectAdd", function(opts)
    if opts.args ~= "" then
      M.add(opts.args)
    else
      M.add_prompt()
    end
  end, { nargs = "?", complete = "dir" })

  vim.api.nvim_create_user_command("ProjectOpen", M.pick, {})
end

return M
