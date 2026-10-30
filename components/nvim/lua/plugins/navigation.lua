local function_body_parents = {
  function_declaration = true,
  method_declaration = true,
  func_literal = true,
}

-- Fold start line -> body start line (both 1-based) for wrapped signatures.
local body_starts = {}

-- A single-line signature yields a function fold and an identical block fold;
-- drop the duplicate. With a wrapped signature the block starts on a later
-- line, so keep it and remember where the body starts.
local function treesitter_folds(bufnr)
  body_starts[bufnr] = nil
  local ranges = require("ufo.provider.treesitter").getFolds(bufnr)
  if not ranges then
    return ranges
  end

  local function_ends = {}
  local blocks_by_end = {}
  for _, range in ipairs(ranges) do
    if function_body_parents[range.kind] then
      function_ends[range.startLine] = range.endLine
    elseif range.kind == "block" then
      blocks_by_end[range.endLine] = blocks_by_end[range.endLine] or {}
      table.insert(blocks_by_end[range.endLine], range.startLine)
    end
  end

  local starts = {}
  body_starts[bufnr] = starts
  for fold_start, fold_end in pairs(function_ends) do
    local body_start
    for _, block_start in ipairs(blocks_by_end[fold_end] or {}) do
      if block_start > fold_start and (not body_start or block_start < body_start) then
        body_start = block_start
      end
    end
    if body_start then
      starts[fold_start + 1] = body_start + 1
    end
  end

  local filtered = {}
  for _, range in ipairs(ranges) do
    local duplicate = range.kind == "block" and function_ends[range.startLine] == range.endLine
    if not duplicate then
      table.insert(filtered, range)
    end
  end
  return filtered
end

local function trim_chunks(chunks, trim_leading)
  local result = {}
  local leading = trim_leading
  for _, chunk in ipairs(chunks) do
    local text = chunk[1]
    if leading then
      text = text:gsub("^%s+", "")
      if text ~= "" then
        leading = false
        table.insert(result, { text, chunk[2] })
      end
    else
      table.insert(result, { text, chunk[2] })
    end
  end

  while #result > 0 do
    local chunk = result[#result]
    local text = chunk[1]:gsub("%s+$", "")
    if text == "" then
      table.remove(result)
    else
      chunk[1] = text
      break
    end
  end
  return result
end

local function last_char(chunks)
  for i = #chunks, 1, -1 do
    local char = chunks[i][1]:match "(%S)%s*$"
    if char then
      return char
    end
  end
end

local function first_char(chunks)
  for _, chunk in ipairs(chunks) do
    local char = chunk[1]:match "^%s*(%S)"
    if char then
      return char
    end
  end
end

local function strip_trailing_comma(chunks)
  local chunk = chunks[#chunks]
  if not chunk then
    return
  end

  local text = chunk[1]:gsub(",%s*$", "")
  if text ~= chunk[1] then
    if text == "" then
      table.remove(chunks)
    else
      chunk[1] = text
    end
  end
end

local function is_comment_chunk(chunk)
  local hl = chunk[2]
  if type(hl) == "string" and hl:lower():find("comment", 1, true) then
    return true
  end

  -- Tree-sitter highlight chunks use numeric IDs, so identify comment chunks
  -- by the marker that starts them.
  return type(hl) == "number" and (chunk[1]:match "^%s*//" ~= nil or chunk[1]:match "^%s*/%*" ~= nil)
end

-- Signature comments cannot be represented on a single folded line, so keep
-- the code around them and drop the comment text.
local function strip_comments(chunks, in_block_comment)
  local result = {}
  local block = in_block_comment

  for _, chunk in ipairs(chunks) do
    local text = chunk[1]
    local comment = is_comment_chunk(chunk)
    local start = 1

    while start <= #text do
      if block then
        local close = text:find("*/", start, true)
        if close then
          block = false
          start = close + 2
        else
          start = #text + 1
        end
      elseif comment then
        local line_comment = text:find("//", start, true)
        local block_comment = text:find("/*", start, true)
        if line_comment and (not block_comment or line_comment < block_comment) then
          if line_comment > start then
            table.insert(result, { text:sub(start, line_comment - 1), chunk[2] })
          end
          return result, block
        elseif block_comment then
          if block_comment > start then
            table.insert(result, { text:sub(start, block_comment - 1), chunk[2] })
          end
          block = true
          start = block_comment + 2
        else
          table.insert(result, { text:sub(start), chunk[2] })
          start = #text + 1
        end
      else
        table.insert(result, { text:sub(start), chunk[2] })
        start = #text + 1
      end
    end
  end

  return result, block
end

local function join_signature(lines)
  local chunks = {}
  local in_block_comment = false
  for i, line in ipairs(lines) do
    line, in_block_comment = strip_comments(line, in_block_comment)
    line = trim_chunks(line, i > 1)
    if #line > 0 then
      if #chunks > 0 then
        local previous = last_char(chunks)
        local next_char = first_char(line)
        if previous == "," and (next_char == ")" or next_char == "]") then
          strip_trailing_comma(chunks)
        elseif not (previous == "(" or previous == "[" or next_char == ")" or next_char == "]") then
          table.insert(chunks, { " ", "UfoFoldedFg" })
        end
      end
      vim.list_extend(chunks, line)
    end
  end
  return chunks
end

local function fit_chunks(chunks, width, truncate)
  local result = {}
  local current_width = 0
  for _, chunk in ipairs(chunks) do
    local text = chunk[1]
    local chunk_width = vim.fn.strdisplaywidth(text)
    if current_width + chunk_width <= width then
      table.insert(result, chunk)
      current_width = current_width + chunk_width
    else
      local remaining = width - current_width
      if remaining > 0 then
        text = truncate(text, remaining)
        if text ~= "" then
          table.insert(result, { text, chunk[2] })
        end
      end
      break
    end
  end
  return result
end

-- Keep the signature and the closing bracket visible on the folded line.
local function fold_virt_text_handler(virt_text, lnum, end_lnum, width, truncate, ctx)
  local last_line = vim.trim(vim.api.nvim_buf_get_lines(ctx.bufnr, end_lnum - 1, end_lnum, false)[1] or "")
  local closing = last_line:match "^[%]%)}]+" or ""
  local suffix = " ⋯ " .. closing
  local target_width = math.max(width - vim.fn.strdisplaywidth(suffix), 0)
  local body_lnum = body_starts[ctx.bufnr] and body_starts[ctx.bufnr][lnum]
  local chunks = virt_text

  if body_lnum and ctx.get_fold_virt_text then
    local lines = { virt_text }
    for line = lnum + 1, body_lnum do
      table.insert(lines, ctx.get_fold_virt_text(line))
    end
    chunks = join_signature(lines)
  end

  local result = fit_chunks(chunks, target_width, truncate)
  table.insert(result, { " ⋯ ", "NonText" })
  table.insert(result, { closing, "TSPunctBracket" })
  return result
end

return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = { "BufReadPost", "BufNewFile" },
    init = function()
      vim.o.foldcolumn = "0"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    opts = {
      provider_selector = function()
        return { treesitter_folds, "indent" }
      end,
      enable_get_fold_virt_text = true,
      fold_virt_text_handler = fold_virt_text_handler,
    },
    config = function(_, opts)
      require("ufo").setup(opts)

      local ufo = require "ufo"
      local map = vim.keymap.set

      map("n", "zR", ufo.openAllFolds, { desc = "Open all folds" })
      map("n", "zM", ufo.closeAllFolds, { desc = "Close all folds" })
      map("n", "zr", ufo.openFoldsExceptKinds, { desc = "Open folds except kinds" })
      map("n", "zm", ufo.closeFoldsWith, { desc = "Close folds with kind" })
      map("n", "K", function()
        if not ufo.peekFoldedLinesUnderCursor() then
          vim.lsp.buf.hover()
        end
      end, { desc = "Peek fold or LSP hover" })
    end,
  },

  -- Helix-style motions; keep the built-in diff-mode `]c`/`[c` behavior.
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter-textobjects").setup {
        move = { set_jumps = true },
      }

      local map = vim.keymap.set
      local modes = { "n", "x", "o" }
      local move = require "nvim-treesitter-textobjects.move"

      local function has_parser()
        local ok, parser = pcall(vim.treesitter.get_parser, 0, nil, { error = false })
        return ok and parser ~= nil
      end

      local function jump(method, capture)
        return function()
          if has_parser() then
            move[method](capture, "textobjects")
          end
        end
      end

      local function jump_comment(method, fallback)
        return function()
          if vim.wo.diff and vim.api.nvim_get_mode().mode == "n" then
            vim.cmd(("normal! %d%s"):format(vim.v.count1, fallback))
          elseif has_parser() then
            move[method]("@comment.outer", "textobjects")
          end
        end
      end

      map(modes, "]f", jump("goto_next_start", "@function.outer"), { desc = "Next function" })
      map(modes, "[f", jump("goto_previous_start", "@function.outer"), { desc = "Previous function" })
      map(modes, "]t", jump("goto_next_start", "@class.outer"), { desc = "Next type" })
      map(modes, "[t", jump("goto_previous_start", "@class.outer"), { desc = "Previous type" })
      map(modes, "]a", jump("goto_next_start", "@parameter.inner"), { desc = "Next parameter" })
      map(modes, "[a", jump("goto_previous_start", "@parameter.inner"), { desc = "Previous parameter" })
      map(modes, "]c", jump_comment("goto_next_start", "]c"), { desc = "Next comment" })
      map(modes, "[c", jump_comment("goto_previous_start", "[c"), { desc = "Previous comment" })
    end,
  },
}
