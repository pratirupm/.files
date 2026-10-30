# AGENTS.md

Personal NvChad v2.5 config for Go/Lua editing. Edit this repo, never `~/.local/share/nvim/lazy/` (regenerated/replaced).

## Layout and load order

- `init.lua`: set `base46_cache` and leader first, prepend lazy.nvim, `lazy.setup` (NvChad then `plugins`), load the `defaults`/`statusline` base46 caches, then `options`/`autocmds`; `mappings` is deferred with `vim.schedule`. Do not reorder, and do not expect mappings to exist during startup.
- `lua/chadrc.lua` must match `NvChad/ui` v3.0's `nvconfig.lua`; theme is `vague`; NvChad is pinned to v2.5, `ui`/`base46` to v3.0. Its tabufline has `lazyload = false`, order `{ "tabs" }`, and the custom `tabs` module from `configs/tabufline.lua`; buffers live in `winbar`.
- `lua/plugins/init.lua` and auto-imported `lua/plugins/*.lua` hold specs. NvChad already supplies conform, lspconfig, telescope, nvim-tree, cmp, etc.; override in a same-name spec with `opts`/`config`, never add a duplicate plugin.
- `lua/configs/*.lua` wiring: `tabufline.lua` from `chadrc`; `terminal.lua` from `mappings`; `statuscolumn.lua`, `projects.lua`, and `bufferbar.lua` from `options`.
- `projects.lua` stores paths in `stdpath("data")/projects.json` and opens a project in a new `:tcd` tab with `Telescope find_files`. `:ProjectAdd`/`:ProjectOpen` are the command forms; `<C-d>` removes a project in the picker.
- `bufferbar.lua` renders `winbar` per window; it returns empty for nvim-tree, terminal, help, and quickfix windows.
- `nvimtree.lua` puts the tree on the right, closes it after opening, and enables diagnostics. It forces `update_lsp` on `FileType NvimTree`/`BufWritePost` because nvim-tree only reacts to `DiagnosticChanged`.
- `lua/options.lua`, `lua/mappings.lua`, and `lua/autocmds.lua` load NvChad defaults first; custom entries must come after. `mappings.lua` deletes unused NvChad defaults and built-in `]`/`[` list motions, so keep `<leader>e` as the tree toggle and do not re-add `<C-n>`.
- Project tabs use `<C-]>`/`<C-\>` and `<leader>pc`; `pc` warns about unsaved buffers and blocks the last project tab while its terminal has a process. `]t`/`[t` remain treesitter type jumps.
- FileType autocmds force 4-column indentation; `autocmds.lua` applies `wrap` per window on `FileType`/`BufWinEnter` so prose wraps and code resets it. Do not regress to a prose-only callback: `wrap`/`linebreak` are window-local.
- `options.lua` sets `signcolumn=yes` and calls `configs/statuscolumn.lua`, `configs/projects.lua`, and `configs/bufferbar.lua`; `plugins/init.lua` overrides gitsigns with font-independent signs.
- LSP uses the native API: add servers to `vim.lsp.enable` in `configs/lspconfig.lua`, not `require("lspconfig").server.setup()`. NvChad enables `lua_ls` in its `defaults()`. `plugins/fidget.lua` loads fidget.nvim on `LspAttach` for progress.

## Lazy loading and traps

- `plugins/mason.lua` is the declarative Mason install list (`run_on_start` after 3 s). Add editor tools there so fresh clones provision them. Mason cannot install Go, Neovim, a C compiler, or Node/npm.
- `plugins/go.lua` lazy-loads Gopher on `ft=go`, Neotest/DAP on commands/keys; opening Go loads Gopher only. Neotest uses `gotestsum` and `dap-go`; `-race` is off by default (`go_test_args`) for fast runs.
- `plugins/multicursor.lua` lazy-loads on the first `<leader>m`; keys are `mj`/`mk` (below/above), `mn` (next match), `ma` (all), `mc` (clear). Mappings live in `configs/multicursor.lua`; `<leader>ma` no longer opens Telescope marks.
- `plugins/workflow.lua`: visual `ms`/`mr`/`md` are Helix surround aliases; normal `ms`/`mr`/`md` remain marks and visual `S` remains nvim-surround add. `mr`/`md` use `<C-\><C-n>` so multicursor's `<Esc>` layer does not eat them. `mappings.lua` adds `miw`/`maw`/`miW`/`maW` selections and `<A-j>`/`<A-k>` line/selection moves.
- Visual-mode `m` needs the explicit which-key trigger `{ "m", mode = "x" }` in `plugins/init.lua`; auto-triggers skip single-letter prefixes other than `g`/`z`/`Z`. Keep that override a plain `opts` table: the equivalent `opts` function merged to `{}` under NvChad's spec.
- `plugins/navigation.lua` customizes nvim-ufo: `treesitter_folds` drops duplicate block folds, and `fold_virt_text_handler` joins wrapped signatures after stripping comments. Keep `enable_get_fold_virt_text = true` and the provider function, or folded signatures break. `]c`/`[c` retain diff motions; `K` peeks folds then falls back to LSP hover. `<C-Space>`/`<BS>` expand/contract treesitter selection (`an`/`in` remain built-ins).
- `configs/statuscolumn.lua` puts git signs and fold markers in one column (`foldcolumn=0`); a fold marker replaces the sign on fold starts and inherits the GitSigns highlight. Diagnostics render to the right of the line number (`vim.diagnostic.config { signs = false }`).
- `configs/terminal.lua` owns one persistent bottom terminal per project cwd (`nvchad.term`, id `mainTerm_<sha256(cwd)>`, 30%), shared by tabs on the same cwd: `<leader>tt`, terminal-mode `<C-t>`, `<C-x>` to exit. Setup deletes NvChad's split/float terminal maps. Last-window close swaps in the alternate buffer (E444).
- `TabClosed` deletes an idle shell but keeps a running one hidden with a warning. `projects.close_tab` calls `guard_close` to block the last project tab while a process runs; detection uses `pgrep -P`/`ps` (and Linux `wchan` for shell builtins), and unknown states are kept hidden. Do not add cross-tab focus or extra terminal maps.
- Treesitter parsers install on demand from `FileType`; `plugins/treesitter.lua` sets `build = false` to disable NvChad's `TSInstallAll`. Do not switch to `install "all"`. This needs the `tree-sitter` CLI (Mason installs it); pending installs retry after `MasonToolsUpdateCompleted`.
- `configs/conform.lua`: Go formats on save with `goimports` then `golines --max-len=80`; Lua is not formatted on save. `:ConformInfo` lazy-loads conform.
- `lazy-lock.json` is generated and committed; do not hand-edit it.

## Prerequisites

Full per-OS commands are in `README.md`. A fresh machine needs Neovim 0.12+, Go, a C compiler, `git`/`curl`/`unzip`/`gzip`/`tar`, Node/npm (Mason HTML/CSS servers), Bun (optional; it does not replace `npm` for Mason's npm installer), `ripgrep`/`fd`, and `stylua` for checks; `lazygit` is optional, and Windows also needs PowerShell and 7-Zip. Mason's bin is prepended to `PATH`, so its `gopls`/`delve` shadow `~/.local/bin`; remove them from `lua/plugins/mason.lua` and uninstall the Mason packages to use external copies.

## Commands

- Load check: `nvim --headless "+qa" 2>&1`; exit status is 0 even for init errors, so read the output.
- Mapping/terminal check: `nvim --headless "+lua require('mappings')" +qa 2>&1`; `+lua` runs before the deferred `mappings`, so inspect the module explicitly.
- Format: `stylua --check .`; `stylua .` fixes.
- Install plugins: `nvim --headless "+Lazy! install" +qa`; restore lockfile: `nvim --headless "+Lazy! restore" +qa`.
- Install Mason tools: `:MasonToolsInstallSync` in a normal session (first launch also runs them after ~3 s).
- Do not use `:Lazy sync` or `:Lazy update` for routine checks; both update plugins and rewrite `lazy-lock.json`.
- No test suite, build, or CI. For keymap/which-key/terminal behavior use a real UI (`nvim --embed` + `uiAttach`, or a pty); headless `feedkeys` gave misleading results.
- Go tooling: `:lsp` or `:checkhealth vim.lsp`, `:Mason`, `:checkhealth gopher`. `:LspInfo` is not defined on Neovim 0.12.

## Style

- Follow `.stylua.toml`: 2 spaces, 120 columns, double quotes, no call parentheses (`require "foo"` unless chaining).
- `README.md` documents user-facing keymaps and UI behavior plus per-OS installs; update it when behavior changes.
