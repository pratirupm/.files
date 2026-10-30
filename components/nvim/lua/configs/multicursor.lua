local mc = require "multicursor-nvim"

mc.setup()

local map = vim.keymap.set

-- Add cursors above or below the main cursor.
map({ "n", "x" }, "<leader>mj", function()
  mc.lineAddCursor(1)
end, { desc = "multicursor add cursor below" })

map({ "n", "x" }, "<leader>mk", function()
  mc.lineAddCursor(-1)
end, { desc = "multicursor add cursor above" })

-- Add matches of the word/selection under the cursor.
map({ "n", "x" }, "<leader>mn", function()
  mc.matchAddCursor(1)
end, { desc = "multicursor add next match" })

map({ "n", "x" }, "<leader>ma", mc.matchAllAddCursors, { desc = "multicursor add all matches" })
map({ "n", "x" }, "<leader>mc", mc.clearCursors, { desc = "multicursor clear cursors" })

-- These mappings only apply while multiple cursors are active.
mc.addKeymapLayer(function(layerSet)
  layerSet({ "n", "x" }, "<Esc>", function()
    if not mc.cursorsEnabled() then
      mc.enableCursors()
    else
      mc.clearCursors()
    end
  end, { desc = "multicursor clear cursors" })
end)
