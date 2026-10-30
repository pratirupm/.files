# Personal Neovim config

A personal NvChad v2.5 setup focused on Go and Lua editing, Helix-style navigation and surround, multiple cursors, and DAP/Neotest. NvChad is loaded as a lazy.nvim plugin; this repository contains the user overrides and additions.

# Fresh machine

Mason cannot install the Go SDK, Neovim, a C compiler, or Node.js/npm. Install these system prerequisites first:

- Go toolchain
- Neovim 0.12 or newer
- A C compiler, `git`, and `curl`
- `unzip`, `gzip`, and `tar` (GNU tar on Linux)
- Node.js and `npm` for the Mason-installed HTML/CSS language servers
- Bun (optional; it does not replace `npm` for Mason's npm installer)
- `ripgrep` and `fd` for Telescope
- `lazygit` (optional, for the `<leader>gg` Git UI)
- Windows only: PowerShell and 7-Zip for Mason's archive extraction

## Linux

### Debian / Ubuntu

```sh
sudo apt update
sudo apt install -y build-essential git curl unzip gzip tar nodejs npm ripgrep fd-find golang-go neovim
# Debian/Ubuntu install the fd binary as fdfind.
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
```

### Fedora

```sh
sudo dnf install -y gcc make git curl unzip gzip tar nodejs npm ripgrep fd-find golang neovim
```

### Fedora Silverblue

Silverblue is immutable, so install packages into the base image with `rpm-ostree` and reboot:

```sh
sudo rpm-ostree install gcc make git curl unzip gzip tar nodejs npm ripgrep fd-find golang neovim
systemctl reboot
```

Alternatively, install Linuxbrew below; it avoids layering packages but still needs the system compiler, `make`, Git, curl, unzip, and tar.

### Arch Linux

```sh
sudo pacman -S --needed base-devel git curl unzip gzip tar nodejs npm ripgrep fd go neovim lazygit
```

On other distributions, install the equivalent packages; Linuxbrew below is a fallback.

### Linuxbrew (any distribution)

Install Homebrew, then the tools:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew install go neovim node ripgrep fd lazygit
```

Linuxbrew uses the host compiler; install `gcc`, `make`, `git`, `curl`, `unzip`, and `tar` with your distribution first. Add the `brew shellenv` line to your shell profile if it is not already there.

`lazygit` is optional; install it where your package manager provides it.

## macOS

```sh
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install go neovim node ripgrep fd lazygit
```

The Xcode command-line tools provide the compiler and `make`; macOS already includes Git, curl, tar, unzip, and gzip.

## Windows

In PowerShell, install the native tools with `winget`:

```powershell
winget install --id Git.Git -e
winget install --id GoLang.Go -e
winget install --id Neovim.Neovim -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id BurntSushi.ripgrep.MSVC -e
winget install --id sharkdp.fd -e
winget install --id 7zip.7zip -e
winget install --id JesseDuffield.lazygit -e
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
```

In the Build Tools installer, select **Desktop development with C++**. Native Windows uses `%LOCALAPPDATA%\nvim` for Neovim's config.

For WSL2, run `wsl --install -d Ubuntu` from PowerShell, then follow the Debian/Ubuntu steps inside WSL.

Before cloning, open a new terminal and check `nvim --version` (0.12+) and `go version`; use Linuxbrew or the upstream releases if either is too old.

## Clone the config

Linux, macOS, and WSL2:

```sh
mkdir -p ~/.config
git clone https://github.com/pratirupm/nvim.git ~/.config/nvim
nvim
```

Windows PowerShell:

```powershell
git clone https://github.com/pratirupm/nvim.git "$env:LOCALAPPDATA\nvim"
nvim
```

The first launch installs lazy.nvim plugins, then the missing Mason tools after a short delay. Tree-sitter parsers that are not bundled with Neovim, including Go, are installed the first time a file of that language is opened. If a Go buffer was opened while Mason was still installing the language servers, they are attached again automatically once Mason finishes.

For a non-interactive plugin bootstrap:

```sh
nvim --headless "+Lazy! install" +qa
```

Then launch Neovim normally once and let Mason finish, or run `:MasonToolsInstallSync` from that session.

# Workflow

| Keys | Action |
| --- | --- |
| `<leader>gg` | Open lazygit |
| `<leader>gf` | Open lazygit for the current file |
| `<leader>dd` | Toggle the diagnostics panel |
| `<leader>dq` | Toggle the quickfix panel |
| `<leader>sr` | Search and replace across the project |
| `u` / `<C-r>` / `U` | Undo / redo / redo (normal mode) |
| `[<Space>` / `]<Space>` | Add an empty line above/below |
| `<A-j>` / `<A-k>` | Move the current line or visual selection down/up |
| `ys` / `cs` / `ds` / visual `S` | Add/change/delete surrounding characters |
| `miw` / `maw` | Select inside/around word |
| `miW` / `maW` | Select inside/around WORD |
| `ms"` / `mr"'` / `md"` | Helix-style add/change/delete surround (visual mode) |

The `ms` / `mr` / `md` aliases work in visual mode, so select first with `miw` and then use `ms"`, `mr"'`, or `md"`; repeat the selection before changing or deleting. Pressing `m` in visual mode shows those choices in which-key. Normal-mode `ms` / `mr` / `md` remain mark commands; use `ys` / `cs` / `ds` without selecting first.

Yanked text is briefly highlighted. `scrolloff` and `sidescrolloff` are set to 8, `confirm` is enabled, floating windows use rounded borders, swap files are disabled, and undo history is persistent. The file explorer sits on the right, closes after opening a file, and shows Git status plus LSP diagnostics in its sign column; diagnostics refresh when the tree opens and after writing a file. Buffer tabs omit per-buffer close buttons and the tabline has no close-all button; use `<leader>x` to close the current buffer.

Go buffers format on save with `goimports` followed by `golines --max-len=80`. Lua format-on-save is disabled; `:ConformInfo` shows the available formatters.

# Files and navigation

| Keys | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fa` | Find all files, including hidden and ignored |
| `<leader>fw` | Live grep |
| `<leader>fb` | Switch buffers |
| `<leader>fo` | Recent files |
| `<leader>e` | Toggle the file tree |
| `<leader>b` / `<leader>x` | New / close buffer |
| `<Tab>` / `<S-Tab>` | Next / previous buffer |
| `gd` / `K` | Definition / hover |
| `grn` / `gra` / `grr` | Rename / code action / references |
| `grt` / `gO` | Type definition / document symbols |
| `]d` / `[d` | Next / previous diagnostic |
| `<leader>dd` / `<leader>dq` | Diagnostics / quickfix panel |
| `<leader>fm` / `<leader>/` | Format / toggle comment |

LSP progress such as indexing and workspace loading is shown by `fidget.nvim` in the bottom-right corner.

# Projects and tabs

| Keys | Action |
| --- | --- |
| `<leader>pa` | Add a project folder |
| `<leader>po` | Open the project picker |
| `<leader>pc` | Close the current tab, warning about unsaved buffers |
| `<C-]>` / `<C-\>` | Previous / next tab |
| `gt` / `gT` | Next / previous tab (standard) |

Each project opens in a real tab with a tab-local working directory (`:tcd`) and immediately shows a Telescope file picker at the project root. The top line shows project tabs labeled by their directory name; the line below shows the current tab’s buffers. In the project picker, `<C-d>` removes the selected project. `:ProjectAdd [path]` and `:ProjectOpen` are also available. `<leader>pc` leaves the last tab open.

# Terminal

| Keys | Action |
| --- | --- |
| `<leader>tt` | Toggle the project terminal |
| `<C-t>` | Toggle the project terminal from terminal mode |
| `<C-x>` | Return to normal mode from terminal mode |

There is one persistent bottom terminal per project directory, shared by tabs on the same directory. Tabs for different projects get different shells. Closing and reopening reuses the shell; if the terminal is the last window, it is replaced by the alternate buffer instead of closing Neovim. Closing a project tab removes an idle terminal; `<leader>pc` refuses to close while a process is running and focuses the terminal instead. Exit the shell to start a fresh one on the next toggle.

# Display and indentation

- Every buffer has an 80-column guide (`colorcolumn=80`).
- Tabs are 4 columns wide everywhere. `expandtab` is on by default, so indentation uses 4 spaces; filetypes that require hard tabs, such as Go and Make, keep tabs at a 4-column width.
- Relative line numbers are enabled.
- The tabline shows project tabs only; buffers are shown on the `winbar` line below it. Each project tab uses its own working directory.
- `cursorlineopt=both` makes `cursorline` highlight both the current line and its line number. The other useful values are `line` (line only) and `number` (number column only).
- Whitespace is visible: tabs show as `» `, trailing spaces as `·`, and non-breaking spaces as `␣`.
- Git signs and fold markers share one column: `│`/`_`/`~`/`┆` show changes, while ``/`` show open/closed folds. On a fold-start line with a change, the fold marker takes the Git sign color, so both states fit in one cell. Diagnostics are shown to the right of the line number, and diagnostic signs are disabled in the left column.
- Code does not wrap. Markdown, plain text, git commit messages, and AsciiDoc soft-wrap.
- Live substitution previews (`inccommand=split`), case-insensitive command-line completion, `shiftround`, capped completion popups, and smoother scrolling/jumps are enabled.

# Code navigation and folds

Tree-sitter textobjects provide Helix-style motions between code structures.

| Keys | Action |
| --- | --- |
| `]f` / `[f` | Next/previous function |
| `]t` / `[t` | Next/previous type/class |
| `]a` / `[a` | Next/previous parameter/argument |
| `]c` / `[c` | Next/previous comment |
| `<C-Space>` | Expand selection to the parent node |
| `<BS>` | Contract selection to the child node (visual mode) |
| `zR` / `zM` | Open/close all folds |
| `zr` / `zm` | Open folds except kinds / close folds by kind |
| `za` | Toggle the fold under the cursor |
| `K` | Peek folded lines, otherwise LSP hover |

Counts work (`3]f`), and jumps are added to the jumplist. `]c` / `[c` keep the built-in diff-mode change motions. `gf` remains available for the built-in file-under-cursor jump. Neovim's `an` / `in` also expand and contract nodes in visual and operator modes.

Folds use `nvim-ufo` with Treesitter and indentation fallbacks. All folds start open (`foldlevel=99`), and the fold level column is hidden (`foldcolumn=0`); fold markers are drawn in the same status column as Git signs (`` open, `` closed), so use `za` to toggle a fold. A folded block keeps its closing bracket visible at the end of the folded line, for example `func main() { ⋯ }`. A wrapped signature is joined onto the folded function line, for example `func New(title string) Task { ⋯ }`.

# Tests and debugging

DAP and Neotest load on first use, so opening a Go file does not start the debugger UI or test adapter.

| Keys | Action |
| --- | --- |
| `<leader>tr` | Run the nearest Go test |
| `<leader>tf` | Run the current Go test file |
| `<leader>ts` | Toggle the test summary |
| `<leader>td` | Debug the nearest Go test |
| `<F5>` | Continue |
| `<F10>` / `<F11>` / `<F12>` | Step over / into / out |
| `<leader>db` | Toggle a breakpoint |
| `<leader>du` | Toggle the DAP UI |

`:Neotest` and the `:Dap*` commands are also available and load their plugins on demand.

# Multiple cursors

`multicursor.nvim` lazy-loads on its first key. Leader is Space.

| Keys | Action |
| --- | --- |
| `<leader>mj` / `<leader>mk` | Add a cursor below/above |
| `<leader>mn` | Add the next match |
| `<leader>ma` | Add all matches |
| `<leader>mc` | Clear all cursors |
| `<Esc>` | Clear cursors while active, or re-enable disabled cursors |

Insert, delete, and visual-mode changes apply to every active cursor.

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!
