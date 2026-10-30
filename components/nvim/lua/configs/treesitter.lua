local installing = {}

local function ensure_parser(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local ft = vim.bo[buf].filetype
  if ft == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(ft)
  if not lang then
    return
  end

  -- Loading the parser is the cheapest reliable way to tell whether it exists.
  local ok, loaded = pcall(vim.treesitter.language.add, lang)
  if ok and loaded then
    return
  end

  local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
  if not has_parsers or not parsers[lang] or installing[lang] then
    return
  end

  -- nvim-treesitter uses the tree-sitter CLI for parser installation.
  if vim.fn.executable "tree-sitter" == 0 then
    return
  end

  installing[lang] = true

  require("nvim-treesitter").install(lang):await(function(err)
    installing[lang] = nil
    if err then
      return
    end

    vim.schedule(function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.treesitter.language.get_lang(vim.bo[b].filetype) == lang then
          pcall(vim.treesitter.start, b)
        end
      end
    end)
  end)
end

local group = vim.api.nvim_create_augroup("UserOnDemandTreesitter", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(args)
    ensure_parser(args.buf)
  end,
})

-- If a file was opened before Mason finished installing tree-sitter-cli, retry
-- the pending parser installation once Mason is done.
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "MasonToolsUpdateCompleted",
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        ensure_parser(buf)
      end
    end
  end,
})

-- Cover a file passed on the command line, where FileType may have fired
-- before this module was loaded.
vim.schedule(function()
  ensure_parser(vim.api.nvim_get_current_buf())
end)

return {}
