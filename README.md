# nvim.pack

[![Hosted on Codeberg](https://img.shields.io/badge/Hosted_on-Codeberg-2185d0?logo=codeberg)](https://codeberg.org/bwang-dev/nvim.pack) [![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

> **Note:** The canonical repository for this project is hosted on [Codeberg](https://codeberg.org/bwang-dev/nvim.pack). This GitHub repository is maintained solely as a read-only mirror. Please open issues and pull requests on Codeberg.

A minimalist, declarative Neovim configuration built on **Neovim 0.12+'s native `vim.pack`** package management, orchestrated by a custom loading engine (`core.pack`). No third-party plugin manager required.

## Philosophy

- **Zero-latency startup**: Only the colorscheme loads on the first frame; see `nvim-pack bench` for measured startup.
- **Declarative**: All plugin loading logic is centralized in `lua/plugins/init.lua`.
- **On-demand**: Plugins load only when needed (events, keymaps, or deferred).
- **No bloat**: No `lazy.nvim`, `packer.nvim`, or `paq-nvim` — uses native `:packadd`.

## Architecture

The configuration is built on three pillars:

1. **Entry Point (`init.lua`)** — Sets core options, keymaps, autocmds, disables built-ins, and requires the plugin registry.
2. **Plugin Declarations (`lua/plugins/init.lua`)** — Uses `vim.pack.add({ ... }, { load = function() end })` to download plugins *without* adding them to the runtimepath or sourcing them automatically.
3. **Loading Engine (`lua/core/pack.lua`)** — A declarative registry that dictates *when* and *how* plugins are loaded via `:packadd` and `require`.

## Directory Structure

```
nvim.pack/
├── init.lua                 # Entry point
├── lua/
│   ├── core/
│   │   ├── autocmds.lua     # Global autocmds (highlight-yank, auto-save, session, build hooks, LSP log rotation)
│   │   ├── keymaps.lua      # Global keymaps
│   │   ├── native.lua       # Native replacements: lazygit, terminal, bufdelete, gitbrowse, scratch
│   │   ├── options.lua      # Global options
│   │   ├── pack.lua         # The loading engine
│   │   └── surfaces.lua     # Derived float surfaces (3-tier elevation, ColorScheme hook)
│   └── plugins/
│       ├── init.lua         # Plugin declarations & loading registry
│       ├── catppuccin.lua   # Theme (loaded immediately)
│       ├── completion.lua   # blink.cmp (inline ghost text, 200ms docs)
│       ├── debugging.lua    # DAP ecosystem
│       ├── deferred.lua     # render-markdown, snacks.image, colorizer, guess-indent, todo-comments
│       ├── editing.lua      # indent-blankline, rainbow-delimiters, conform
│       ├── git.lua          # gitsigns, diffview
│       ├── heirline.lua     # Statusline
│       ├── lsp.lua          # LSP, Mason, lazydev
│       ├── navigation.lua   # flash, spider
│       ├── opencode.lua     # OpenCode bridge (ask/select/operator)
│       ├── snacks.lua       # Picker, explorer, images
│       ├── tools.lua        # testing, database, diagnostics, productivity
│       ├── treesitter.lua   # TS core, context, textobjects
│       └── ui.lua           # which-key, native snacks replacements (terminal/lazygit/bufdelete/scratch), bigfile, quickfile
└── nvim-pack-lock.json      # Plugin version lock file
```

## Loading Engine

The engine (`lua/core/pack.lua`) processes a registry array. Each entry defines a module and its loading trigger.

### Registry Entry Schema

```lua
{
  mod     = 'domain_file', -- e.g., 'ui' (maps to lua/plugins/ui.lua)
  fn      = 'function',    -- (Optional) e.g., 'which_key' (calls M.which_key())
  packadd = { 'plugin' },  -- Array of plugin dir names to :packadd before loading
  -- Trigger (choose ONE):
  event   = 'UIEnter',     -- Autocmd event(s) (string or array)
  pattern = {'*.rs'},      -- (Optional) autocmd pattern; nil means all files
  keys    = { ... },       -- Array of { '<leader>x', desc = '...', mode = 'n' }
  defer   = 1,             -- Milliseconds to delay via vim.defer_fn
  -- If no trigger is provided, the module loads immediately (synchronously).
}
```

### Loading Timeline

| Phase              | Trigger                  | What Loads                                          |
| ------------------ | ------------------------ | --------------------------------------------------- |
| **Immediate**      | (none — synchronous)     | Catppuccin colorscheme only                         |
| **VimEnter**       | After init, before UI    | Native setup: bigfile guard, keymap wiring (lazygit/terminal/bufdelete/scratch) |
| **UIEnter**        | After first frame        | Heirline, which-key, navigation, editing (visual), ui-select |
| **BufReadPre**     | On file open             | Treesitter, LSP, rustaceanvim, gitsigns, treesitter-context, snacks image (mermaid, `*.md`) |
| **InsertEnter**    | On first insert       | blink.cmp, autopairs                                    |
| **BufWritePre**    | On save                  | conform.nvim (formatting)                           |
| **Keymap**         | On first keypress        | Snacks picker, DAP, testing, database, diffview, opencode, trouble, productivity, surround, grug-far, treesj |
| **Deferred**       | After 1ms idle           | render-markdown, colorizer, guess-indent, todo-comments |

## CLI Tool

The `nvim-pack` binary provides two commands:

### `nvim-pack link`

Link configuration resources to `~/.config/nvim/` as individual symlinks:

```bash
nvim-pack link           # Link all resources (init.lua, lua/, nvim-pack-lock.json)
nvim-pack link --dry-run # Preview changes without executing
```

### `nvim-pack bench`

Benchmark Neovim startup time:

```bash
nvim-pack bench                        # Default: 30 iterations, 200ms settle
nvim-pack bench --iterations 50        # More iterations
nvim-pack bench --top 20               # Show top 20 slowest sources
nvim-pack bench --file /path/to/file   # Open a specific file
```

Thresholds: ≤50ms EXCELLENT, ≤80ms GOOD, ≤120ms FAIR, >120ms SLOW

## Quick Start

### 1. Install the config

```bash
# Option A: Use nvim-pack CLI (recommended)
nvim-pack link

# Option B: Clone directly
git clone https://github.com/plutowang/nvim.pack.git ~/.config/nvim
```

### 2. First launch

On first launch, `vim.pack` will download all declared plugins. After that:

- Treesitter parsers auto-install on first `BufReadPre` (deferred 500ms).
- LSP servers auto-install via Mason on first `BufReadPre`.
- blink.cmp's Rust fuzzy library compiles automatically via `PackChanged` on install/update (requires `cargo`).
- **Existing installations**: Build the Rust library manually once:
  ```bash
  cd ~/.local/share/nvim/site/pack/core/opt/blink.cmp && cargo build --release
  ```

## System Dependencies

### Required

These tools must be installed for core functionality:

| Tool          | Purpose                          | Install                              |
| ------------- | -------------------------------- | ------------------------------------ |
| `git`         | Plugin downloads, version control | macOS built-in or `brew install git` |
| `curl`        | Plugin downloads                 | macOS built-in or `brew install curl`|
| `rg`          | Grep search (Snacks picker, grug-far)| `brew install ripgrep`               |
| `fd`          | File search (Snacks picker)          | `brew install fd`                    |
| `tree-sitter` | Parser compilation               | `cargo install tree-sitter-cli`      |
| `make`        | Build native extensions          | Xcode CLI tools (`xcode-select --install`) |
| `cargo`       | blink.cmp Rust fuzzy library     | `brew install rust`                  |

### Optional — Language Support

Mason auto-installs LSP servers, but some servers need language runtimes:

| Language   | Required Tool    | Install                     | LSP Servers Enabled              |
| ---------- | ---------------- | --------------------------- | -------------------------------- |
| Go         | `go`             | `brew install go`           | `gopls`                          |
| TypeScript | `node` / `npm`   | `brew install node`         | `ts_ls`, `angularls`, `eslint`   |
| Python     | `python3`        | macOS built-in              | `pyright`                        |
| Rust       | `cargo`          | `brew install rust`         | `rust_analyzer`                  |
| Zig        | `zig`            | `brew install zig`          | `zls`                            |
| HTML/CSS   | (none extra)     | —                           | `html`, `tailwindcss`            |
| GraphQL    | (none extra)     | —                           | `graphql`                        |
| Astro      | `node` / `npm`   | `brew install node`         | `astro`                          |
| C/C++      | `clangd`         | `brew install llvm`         | `clangd`                         |

### Optional — Markdown (images & Mermaid diagrams)

Inline rendering in markdown buffers (snacks.nvim `image` module) covers regular images and mermaid code blocks. Mermaid needs the official mermaid-cli converter plus a Chromium-based browser for Puppeteer; non-PNG images are converted by ImageMagick.

Without `magick`/`identify`, the image module disables itself at startup; conversion failures are no longer surfaced as notifications.

| Tool | Purpose | Install |
| ---- | ------- | ------- |
| `mmdc` (mermaid-cli) | Render ` ```mermaid ` blocks to PNG | `brew install mermaid-cli` |
| Chromium-based browser | Puppeteer runtime used by mmdc | existing Chrome, or `brew install --cask google-chrome` |
| ImageMagick | Convert non-PNG images (svg/jpg/webp/…) | `brew install imagemagick-full` |

Use `imagemagick-full`, not the regular `imagemagick` formula — the regular build lacks librsvg/fontconfig and cannot rasterize SVG text (shields.io badges fail with `unable to read font`).

Point Puppeteer at the browser in your shell config (this repo: `terminal/zsh/.zshrc`):

```zsh
export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
```

Note: the `chromium` cask is disabled (Gatekeeper, 2026-09-01) — use a signed Chromium-based browser (Chrome, Brave, Edge). Skip this section if you don't render images/mermaid in markdown.

## Adding or Modifying Plugins

### To add a new plugin

1. **Declare it**: Add the source to the `vim.pack.add` list in `lua/plugins/init.lua`.
2. **Configure it**: Add a setup function to the appropriate domain file in `lua/plugins/`.
3. **Register it**: Add an entry to the `pack.setup` registry in `lua/plugins/init.lua`, specifying `mod`, `fn`, `packadd`, and the loading trigger.

### To modify an existing plugin

1. Locate its domain file in `lua/plugins/`.
2. Modify the specific exported function (e.g., `M.format()` in `editing.lua`).

### To remove a plugin

1. **Remove the declaration**: Delete the plugin from the `vim.pack.add` list in `lua/plugins/init.lua`.
2. **Remove the registry entry**: Delete the corresponding entry from the `pack.setup` registry in `lua/plugins/init.lua` (the entry with `mod = '...'` that references the plugin in its `packadd` array).
3. **Remove from disk**: Delete the plugin directory from `~/.local/share/nvim/site/pack/core/opt/<PluginName>`.
4. **Clean the lock file** (optional but recommended): Remove the plugin entry from `nvim-pack-lock.json` to keep it in sync. If `vim.pack` auto-repairs it back on next startup, the plugin directory still exists on disk — remove that first, then the lock entry will stay removed.

## Native 0.12 Features

- **Diff**: `'diffopt'` uses `inline:word` and `algorithm:histogram`. diffview is independent; gitsigns derives its diff algorithm from `'diffopt'`.
- **UI2**: `vim._core.ui2` is enabled when a UI is attached. `cmdheight=1` keeps the command line visible and the view stable; it remains `1` in headless/CI. If messages spill, increase it to `2`.
- **Borders**: `'winborder'` and `'pumborder'` are `rounded`; explicit plugin borders still win. The `nvim_open_win` shim now only applies `style='minimal'`.
- **Surfaces**: `lua/core/surfaces.lua` derives three elevation tiers from the active palette on `ColorScheme` (semantic layer when it stays within a 1.02–1.30 contrast band, RGB math otherwise). Float, popup-menu, blink, which-key, trouble and snacks groups all resolve to those tiers; `FloatBorder.bg` is locked to `NormalFloat.bg` so no terminal cell bleeds through. Re-derivation costs ~0.7 ms and only runs on theme changes.
- **Folding**: native treesitter folds; `'foldtext'` is empty, so folded lines show the first line with syntax highlighting; no fold-text plugin.
- **Diagnostics**: `'virtual_lines.current_line'` shows diagnostics only under the cursor; severity underlines use the theme palette and inlay hints are unboxed italics. Custom Nerd Font signs remain.
- **LSP progress**: `LspProgress` drives a native OSC 9;4 terminal progress bar. Ghostty resets an idle bar after ~15 s; there is no keepalive timer and no polling.
- **Statusline**: an event-driven active-token cache drives an O(1) provider; idle client names remain visible; `WinEnter` keeps the global statusline in sync when switching windows.
- **Canvas**: `'fillchars'` blanks `eob`/`fold`; split and float borders take their colour from `WinSeparator`/`FloatBorder`.

## Known Pitfalls

1. **`packadd` Dependencies**: If a plugin requires another plugin to function, you MUST include the dependency in the `packadd` array of the registry entry.
2. **`vim.ui.select` Overrides**: `snacks.picker` replaces `vim.ui.select` when `Snacks.setup` runs at `VimEnter`. Keep picker setup early; a shim that restores the original before calling it silently falls back to the built-in prompt.
3. **Headless Mode**: The `core.pack` engine does NOT bypass lazy loading in headless mode. Trigger the specific event or keymap to load a plugin during a headless script.
4. **Augroup Collisions**: The engine names augroups `pack-<mod>` or `pack-<mod>-<fn>` — the `-<fn>` suffix is omitted when the entry has no `fn`. Never manually create augroups with this naming scheme.
5. **Keymap Replay**: The engine's keymap trigger uses `nvim_feedkeys` to replay the initial keypress. Ensure the plugin's actual keymap exactly matches the trigger keymap.
6. **Event-Driven Module Setup**: Plugins that set up submodules on events (e.g., snacks.nvim `image` on `BufReadPre`) miss the in-flight event when loaded lazily *during* that event. Run the module setup explicitly after `setup()` — see `snacks.image.setup()` in `M.images()` (`lua/plugins/deferred.lua`).

## Troubleshooting

### blink.cmp "No fuzzy matching Library found"

This error appears when the Rust fuzzy library hasn't been compiled. blink.cmp's error message references `lazy.nvim` (its most common plugin manager), but the fix is the same regardless of plugin manager:

```bash
cd ~/.local/share/nvim/site/pack/core/opt/blink.cmp && cargo build --release
```

The `PackChanged` autocmd runs this automatically on install/update. If you don't have `cargo` installed, the config falls back to the Lua fuzzy implementation via `fuzzy.implementation = 'prefer_rust'` in `lua/plugins/completion.lua`. To force Lua-only matching, change it to `'lua'`.

### snacks `checkhealth` shows `notifier: is not ready`

Expected. The `notifier` module is intentionally not configured, so `vim.notify` stays native; snacks still runs the notifier health probe and reports it as not ready. No action needed.

### snacks `checkhealth` shows `tectonic`/`pdflatex` missing

Only LaTeX `math` fences need them. Mermaid and regular images are unaffected. Install `tectonic` (or `pdflatex`) if you want math rendering; otherwise ignore the error.

### snacks `checkhealth` warns about disabled modules

`bigfile`, `dashboard`, `input`, `quickfile`, `scope`, `scroll`, `statuscolumn`, and `words` are deliberately left unconfigured to avoid timers/autocmds. Their `setup {disabled}` warnings are expected. Missing treesitter parsers (`latex`, `norg`, `scss`, `svelte`, `typst`, `vue`) only affect image rendering in those document languages; markdown/mermaid works with the installed parsers.
