# nvim.pack

A minimalist, declarative Neovim configuration built on **Neovim 0.12+'s native `vim.pack`** package management, orchestrated by a custom loading engine (`core.pack`). No third-party plugin manager required.

## Philosophy

- **Zero-latency startup**: Only the colorscheme loads on the first frame (~18ms perceived interactive).
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
│   │   └── pack.lua         # The loading engine
│   └── plugins/
│       ├── init.lua         # Plugin declarations & loading registry
│       ├── catppuccin.lua   # Theme (loaded immediately)
│       ├── completion.lua   # blink.cmp
│       ├── debugging.lua    # DAP ecosystem
│       ├── deferred.lua     # render-markdown, colorizer, guess-indent, todo-comments
│       ├── editing.lua      # indent-blankline, rainbow-delimiters, conform
│       ├── git.lua          # gitsigns, diffview
│       ├── heirline.lua     # Statusline
│       ├── lsp.lua          # LSP, Mason, lazydev
│       ├── navigation.lua   # neo-tree, flash, spider
│       ├── telescope.lua    # Fuzzy finder
│       ├── tools.lua        # testing, database, diagnostics, productivity
│       ├── treesitter.lua   # TS core, context, textobjects
│       └── ui.lua           # which-key, native snacks replacements (terminal/lazygit/bufdelete/scratch), bigfile, quickfile
└── eval_startuptime.zig     # Startup benchmark tool
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
| **BufReadPre**     | On file open             | Treesitter, LSP, rustaceanvim, gitsigns, treesitter-context |
| **InsertEnter**    | On first insert       | blink.cmp, autopairs                                    |
| **BufWritePre**    | On save                  | conform.nvim (formatting)                           |
| **Keymap**         | On first keypress        | Telescope, DAP, testing, database, diffview, trouble, productivity, surround, grug-far, treesj |
| **Deferred**       | After 1ms idle           | render-markdown, colorizer, guess-indent, todo-comments |

## Quick Start

### 1. Symlink the config

```bash
# Option A: Direct symlink (replaces existing config)
ln -sf ~/projects/personal/term.conf/nvim.pack ~/.config/nvim

# Option B: Isolated via NVIM_APPNAME (keeps existing config)
NVIM_APPNAME=nvim.pack nvim
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
| `rg`          | Grep search (Telescope, grug-far)| `brew install ripgrep`               |
| `fd`          | File search (Telescope)          | `brew install fd`                    |
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

## Verification & Debugging

```bash
# Syntax check all Lua files
luac -p nvim.pack/lua/**/*.lua

# Headless startup (must exit cleanly with code 0)
nvim --headless +quit; echo $?

# Startup benchmark (covers immediate + VimEnter + BufReadPre + UIEnter plugins)
cd nvim.pack && zig run eval_startuptime.zig
# Options: --file <path> --iterations <n> --warmup <n> --settle <ms> --top <n>
# Thresholds: <=50ms EXCELLENT, <=80ms GOOD, <=120ms FAIR, >120ms SLOW

# Inside Neovim: check loaded modules
:lua print(vim.inspect(require('core.pack').loaded()))

# Inside Neovim: run healthcheck
:checkhealth
```

## Known Pitfalls

1. **`packadd` Dependencies**: If a plugin requires another plugin to function, you MUST include the dependency in the `packadd` array of the registry entry.
2. **`vim.ui.select` Overrides**: Plugins that override core Neovim functions (like `telescope-ui-select`) MUST be loaded early (on `UIEnter`), even if the main plugin is loaded lazily via keymaps.
3. **Headless Mode**: The `core.pack` engine does NOT bypass lazy loading in headless mode. Trigger the specific event or keymap to load a plugin during a headless script.
4. **Augroup Collisions**: The engine creates augroups named `'pack-' .. entry.mod .. '-' .. entry.fn`. Never manually create augroups with this naming scheme.
5. **Keymap Replay**: The engine's keymap trigger uses `nvim_feedkeys` to replay the initial keypress. Ensure the plugin's actual keymap exactly matches the trigger keymap.

## Troubleshooting

### nvim-treesitter `master` vs `main` Branch (CRITICAL)

The `master` branch of `nvim-treesitter` is a **legacy rewrite** incompatible with Neovim 0.12+. This configuration uses the **`main` branch** (a complete ground-up rewrite).

**`master` branch bug — Shift+K (LSP hover) crash**: The `master` branch ships a `query_predicates.lua` that crashes Neovim when LSP hover opens a markdown float buffer.

**Fix**: Switch to the `main` branch:
```bash
git -C ~/.local/share/nvim/site/pack/core/opt/nvim-treesitter checkout main
```

### The `lazy.nvim` Ghost Symlink Bug (No Highlighting)

If migrating from `lazy.nvim`, broken symlinks in `~/.local/share/nvim/site/queries/` can prevent Treesitter highlighting.

**Fix**:
```bash
rm -rf ~/.local/share/nvim/site/queries
rm -rf ~/.local/share/nvim/site/parser
# Open Neovim to trigger auto-install
nvim
```

### LSP Log Growing Too Large

The config automatically truncates the LSP log file on `VimEnter` if it exceeds 10 MB. If you need to manually clear it:

```vim
:lua vim.fn.delete(vim.lsp.log.get_filename())
```

### blink.cmp "No fuzzy matching Library found"

This error appears when the Rust fuzzy library hasn't been compiled. blink.cmp's error message references `lazy.nvim` (its most common plugin manager), but the fix is the same regardless of plugin manager:

```bash
cd ~/.local/share/nvim/site/pack/core/opt/blink.cmp && cargo build --release
```

The `PackChanged` autocmd runs this automatically on install/update. If you don't have `cargo` installed, the config falls back to the Lua fuzzy implementation via `fuzzy.implementation = 'prefer_rust'` in `lua/plugins/completion.lua`. To force Lua-only matching, change it to `'lua'`.

## TODO: LSP Server Dynamic Configuration

`vim.lsp.config` does not support `on_new_config` (a `nvim-lspconfig`-specific feature). Dynamic per-project configuration is achieved via `root_dir` as a function, which calls `vim.lsp.config()` to update `cmd` before the server starts. **Limitation**: in multi-project workspaces, the last opened project wins for `cmd` updates.

### Implemented

- **angularls**: Uses `root_dir` function to dynamically set `--tsProbeLocations`, `--ngProbeLocations`, and `--angularCoreVersion` based on project `node_modules` and `package.json`. Falls back to Mason package's `node_modules`.

### Not Yet Implemented

- **astro**: Sets `init_options.typescript.tsdk` from project TypeScript installation.
- **tailwindcss**: Complex `root_dir` function that checks for Tailwind config files and `tailwindcss` in `package.json`.
- **zls**: Adds `--config-path` flag when `zls.json` exists in the project root.

To implement these, add a `root_dir` function to the relevant server entry in `lua/plugins/lsp.lua`. See the `nvim-lspconfig` repository's `lsp/` directory for reference implementations.
