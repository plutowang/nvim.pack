---
name: nvim-pack
description: Auto-apply when working on the Neovim configuration in the nvim.pack/ directory. Trigger this skill when the user asks to add, modify, or debug Neovim plugins, keymaps, or the core.pack loading engine.
---

# Neovim `nvim.pack` Architecture Expert

You are an expert in the custom `nvim.pack` Neovim configuration architecture. This configuration explicitly **bypasses traditional plugin managers** (like `lazy.nvim` or `packer.nvim`) in favor of Neovim 0.12+'s native `vim.pack` package management, orchestrated by a custom, declarative loading engine (`core.pack`).

**Rule #1:** Never suggest using `lazy.nvim`, `packer`, or `paq` commands. All plugin management is handled via `vim.pack.add` and the `core.pack` registry.

## 1. Architecture Overview

The configuration is built on three pillars:

1. **Entry Point (`init.lua`)**: Sets core options, keymaps, autocmds, disables built-ins, and requires the plugin registry.
2. **Plugin Declarations (`lua/plugins/init.lua`)**: Uses `vim.pack.add({ ... }, { load = function() end })` to download plugins *without* adding them to the `runtimepath` or sourcing them automatically.
3. **Loading Engine (`lua/core/pack.lua`)**: A declarative registry that dictates *when* and *how* plugins are loaded (via `:packadd` and `require`).

## 2. Directory Structure

The configuration is strictly organized into domains to minimize file count:

```text
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
│       ├── deferred.lua     # markdown, colorizer, guess-indent, todo-comments
│       ├── editing.lua      # indent-blankline, rainbow-delimiters, conform
│       ├── git.lua          # gitsigns, diffview
│       ├── heirline.lua     # Statusline
│       ├── lsp.lua          # LSP, Mason, lazydev
│       ├── navigation.lua   # neo-tree, flash, spider
│       ├── telescope.lua    # Fuzzy finder
│       ├── tools.lua        # testing, database, diagnostics, productivity
│       ├── treesitter.lua   # TS core, context, textobjects
│       └── ui.lua           # which-key, native snacks replacements (terminal/lazygit/bufdelete/scratch), bigfile, quickfile
```

## 3. The Loading Engine (`core.pack`)

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

### Loading Triggers & Timeline

1. **Immediate (Startup)**: No trigger specified. Used *only* for the colorscheme (`catppuccin`) to prevent flashing.
2. **`VimEnter` Event**: After init completes, before UI renders. Used for native feature setup: bigfile guard, and keymap wiring for lazygit/terminal/bufdelete/scratch (`M.snacks`, `M.bigfile`, `M.quickfile` in `ui.lua` — no `packadd` needed since these are native implementations).
3. **`UIEnter` Event**: Non-blocking. Loads immediately after the first frame renders. Used for UI components (`heirline`, `which_key`, `neo-tree`, editing visual plugins).
4. **`BufReadPre` / `BufNewFile` Events**: Core file-level features. Used for `treesitter`, `lsp`, `gitsigns`.
5. **`InsertEnter` / `CmdlineEnter` Events**: Used for completion (`blink.cmp`) and insert helpers (`autopairs`).
6. **`BufWritePre` Event**: Used for formatting (`conform`).
7. **Keymaps (`keys`)**: Sets a temporary keymap. On first press, it deletes the temp keymap, loads the plugin, and replays the keypress. Used for `telescope`, `debugging`, `testing`, `surround`, `grug-far`, `treesj`.
8. **Deferred (`defer`)**: Idle loading after *N* milliseconds. Used for low-priority visual enhancements (`colorizer`, `render-markdown`).

## 4. Plugin File Patterns

Domain files in `lua/plugins/` (like `ui.lua` or `editing.lua`) export multiple setup functions to allow independent loading of related plugins.

**Example: `lua/plugins/ui.lua`**

```lua
local M = {}

function M.which_key()
  require('which-key').setup({ ... })
end

-- Native replacement (no plugin required — wires keymaps only)
function M.snacks()
  local native = require('core.native')
  vim.keymap.set('n', '<leader>gg', native.lazygit, { desc = 'Lazy Git' })
  vim.keymap.set('n', '<leader>tt', native.terminal, { desc = 'Terminal' })
  -- ... other native keymaps
end

return M
```

**Corresponding Registry Entries (`lua/plugins/init.lua`)**:

```lua
{ mod = 'ui', fn = 'which_key', event = 'UIEnter', packadd = { 'which-key.nvim' } },
-- Native entries have NO packadd — they load lua/core/native.lua directly
{ mod = 'ui', fn = 'snacks',    event = 'VimEnter' },
{ mod = 'ui', fn = 'bigfile',   event = 'VimEnter' },
{ mod = 'ui', fn = 'quickfile', event = 'VimEnter' },
```

If a file only configures one plugin (like `catppuccin.lua`), it can self-configure on `require` and omit the `fn` field in the registry.

## 5. Adding or Modifying Plugins

### To add a new plugin

1. **Declare it**: Add the source to the `vim.pack.add` list in `lua/plugins/init.lua`.
2. **Configure it**: Add a setup function to the appropriate domain file in `lua/plugins/` (e.g., add to `tools.lua`).
3. **Register it**: Add an entry to the `pack.setup` registry in `lua/plugins/init.lua`, specifying the `mod`, `fn`, `packadd` dependencies, and the loading trigger.

### To modify an existing plugin

1. Locate its domain file in `lua/plugins/`.
2. Modify the specific exported function (e.g., `M.format()` in `editing.lua`).

### To remove a plugin

Removing a plugin requires cleanup in **four places** — the config files, the registry, the lock file, and the on-disk plugin directory. **Order matters**: the disk directory must be deleted before the lock file entry, or `vim.pack` will auto-repair the lock file on next startup.

1. **Remove the declaration**: Delete the plugin URL from the `vim.pack.add({ ... })` list in `lua/plugins/init.lua`.
2. **Remove the registry entry**: Delete the corresponding `pack.setup` entry (or remove the plugin name from the `packadd` array if other plugins in the same entry are still needed).
3. **Remove the configuration**: Delete the `require('PluginName').setup(...)` block and any related keymaps from the domain file in `lua/plugins/`.
4. **Delete from disk FIRST**: `rm -rf ~/.local/share/nvim/site/pack/core/opt/<PluginName>`
5. **Clean the lock file**: Remove the plugin entry from `nvim-pack-lock.json`.

> **⚠️ Critical**: If you remove the lock file entry while the plugin directory still exists on disk, `vim.pack` will detect the orphaned directory on next startup, emit a "Repaired corrupted lock data for plugins: PluginName" warning, and **restore the lock file entry automatically**. Always delete the directory from disk first.

## 5.1. LSP Server Configuration (Native vim.lsp.config)

This configuration uses **native `vim.lsp.config()` + `vim.lsp.enable()`** instead of `nvim-lspconfig` or `mason-lspconfig`. All server defaults (`cmd`, `filetypes`, `root_markers`) are defined explicitly in `lua/plugins/lsp.lua`.

### Three LSP Server Patterns

Not all LSP servers can use the same setup pattern. Choose the correct pattern based on the server's requirements:

| Pattern | When to Use | Example Servers |
|---------|------------|-----------------|
| **Standard** (`servers` table) | Server works with static `cmd`, `filetypes`, `root_markers` | gopls, ts_ls, lua_ls, zls, html, graphql, astro, tailwindcss, gitlab_ci_ls |
| **Dynamic cmd** (`FileType` autocmd + `vim.lsp.start`) | Server needs runtime cmd resolution (probe paths, versions, project-specific args) | angularls (needs `--tsProbeLocations`, `--ngProbeLocations`, `--angularCoreVersion`) |
| **Plugin-managed** (external plugin handles LSP) | Server is managed by a dedicated plugin with its own lifecycle and configuration | rustaceanvim (manages rust-analyzer; must NOT also be in `servers` table) |

### Pattern 1: Standard — Add to `servers` table

1. **Look up defaults**: Find the server's `cmd`, `filetypes`, `root_markers`, and `single_file_support` from the `nvim-lspconfig` repository (`lsp/` directory or `lua/lspconfig/configs/`).
2. **Look up Mason package name**: Find the corresponding Mason package name (e.g., `lua_ls` → `lua-language-server`).
3. **Add to `servers` table** in `lua/plugins/lsp.lua`:
   ```lua
   server_name = {
     cmd = { 'server-command', '--stdio' },
     filetypes = { 'filetype1', 'filetype2' },
     root_markers = { 'root_file', '.git' },
     single_file_support = true,  -- if applicable
     settings = { ... },  -- if needed
   },
   ```
4. **Add to `lsp_to_mason` mapping** in `lua/plugins/lsp.lua`:
   ```lua
   server_name = 'mason-package-name',
   ```
5. **Verify**: Run `luac -p nvim.pack/lua/plugins/lsp.lua`.

### Pattern 2: Dynamic cmd — `FileType` autocmd + `vim.lsp.start`

Use when `vim.lsp.config` cannot resolve the `cmd` statically (e.g., the server needs project-specific flags resolved at runtime). Neovim snapshots the config BEFORE calling `root_dir`, so updating `vim.lsp.config()` inside `root_dir` does NOT affect the current server start.

1. **Do NOT add to `servers` table** — the server is started manually.
2. **Add a `FileType` autocmd** in `lua/plugins/lsp.lua` (after the `for` loop) that calls `vim.lsp.start()` with the fully resolved config:
   ```lua
   vim.api.nvim_create_autocmd('FileType', {
     group = vim.api.nvim_create_augroup('nvimpack-servername', { clear = true }),
     pattern = { 'filetype1', 'filetype2' },
     callback = function(ev)
       local root = vim.fs.root(ev.buf, { 'root_file' })
       if not root then return end
       -- Resolve dynamic values here
       vim.lsp.start({
         name = 'servername',
         cmd = { 'resolved-command', '--dynamic-flag', resolved_value },
         root_dir = root,
         capabilities = capabilities,
       })
     end,
   })
   ```
3. **Add to `lsp_to_mason` mapping** so Mason installs the server binary.
4. **Verify**: Run `luac -p nvim.pack/lua/plugins/lsp.lua`.

### Pattern 3: Plugin-managed — External plugin handles LSP

Use when a dedicated plugin manages the entire LSP lifecycle (e.g., rustaceanvim for rust-analyzer). The plugin handles server start, configuration, and shutdown.

1. **Do NOT add to `servers` table** — the plugin manages its own client. Adding it would cause duplicate LSP clients.
2. **Add a dedicated pattern-based pack entry** in `lua/plugins/init.lua` so the plugin loads only for relevant filetypes. Use `pattern` to restrict to matching files and expose a no-op `fn` so the pack engine can deduplicate via `mod.fn` key:
   ```lua
   { mod = 'lsp', fn = 'rustacean', event = { 'BufReadPre', 'BufNewFile' }, pattern = { '*.rs' }, packadd = { 'rustaceanvim' } },
   ```
   The plugin self-configures via `ftplugin/rust.lua` when `:packadd`'d — no explicit setup needed.
3. **Add a no-op export** in `lua/plugins/lsp.lua` so the pack engine's `mod[fn]()` call succeeds:
   ```lua
   -- At the end of lsp.lua, in the M table exports section:
   function M.rustacean() end  -- rustaceanvim self-configures via ftplugin
   ```
4. **Keep it in any other module's `packadd`** that needs it (e.g., tools.lua testing) — `:packadd` is idempotent.
5. **Set `vim.g.pluginname` config** (if needed) BEFORE the plugin is loaded. Place it in `lua/plugins/lsp.lua` before the `for` loop, or in the relevant domain file.

### To remove an LSP server

1. Remove the entry from the `servers` table (Pattern 1) or the `FileType` autocmd (Pattern 2) or the dedicated pack entry and `M.fn` export (Pattern 3) in `lua/plugins/init.lua` and `lua/plugins/lsp.lua`.
2. Remove the entry from the `lsp_to_mason` mapping.
3. Check if the Mason package is needed by other tools. If not, remove it from `ensure_installed`.
4. Verify with `luac -p nvim.pack/lua/plugins/lsp.lua`.

### Key relationships

- **`vim.lsp.config(name, config)`**: Defines server configuration (cmd, filetypes, root_markers, settings).
- **`vim.lsp.enable(name)`**: Enables filetype-based auto-attach for a server. Called in the same loop as `vim.lsp.config`.
- **`vim.lsp.start(config)`**: Manually starts an LSP client with a fully resolved config. Used for Pattern 2 (dynamic cmd).
- **`lsp_to_mason` mapping**: Maps lspconfig server names to Mason package names for installation via `mason-tool-installer`.
- **No `nvim-lspconfig` or `mason-lspconfig`**: These plugins are NOT used. Server defaults are defined explicitly.

### Security note

If you need to run Python scripts (e.g., to parse lspconfig defaults from the repository), you MUST run them in Docker:

```bash
docker run --rm --network none -i python:3-alpine python -c "<code>"
```

Never run `python` or `python3` directly on the host system.

## 6. Known Pitfalls & Critical Rules

1. **`packadd` Dependencies**: If a plugin requires another plugin to function (e.g., `lsp` keymaps require `telescope`), you MUST include the dependency in the `packadd` array of the registry entry.
    * *Example*: `{ mod = 'lsp', event = 'BufReadPre', packadd = { 'mason.nvim', 'mason-tool-installer.nvim', 'telescope.nvim', 'plenary.nvim' } }`
2. **`vim.ui.select` Overrides**: Plugins that override core Neovim functions (like `telescope-ui-select`) MUST be loaded early (e.g., on `UIEnter`), even if the main plugin (Telescope) is loaded lazily via keymaps. Otherwise, the override won't be active when other plugins (like LSP code actions) try to use it.
3. **Headless Mode**: The `core.pack` engine does NOT bypass lazy loading in headless mode. If you need a plugin to load during a headless script, you must trigger its specific event or keymap.
4. **Augroup Collisions**: The engine creates augroups named `'pack-' .. entry.mod .. '-' .. entry.fn`. Never manually create augroups with this naming scheme.
5. **Keymap Replay**: The engine's keymap trigger uses `nvim_feedkeys` to replay the initial keypress. Ensure the plugin's actual keymap exactly matches the trigger keymap, or the replay will fall through to default Neovim behavior.
6. **Lock File Auto-Repair**: `vim.pack` auto-repairs entries in `nvim-pack-lock.json` if the plugin directory still exists on disk. When removing a plugin, you **must** delete the directory from `~/.local/share/nvim/site/pack/core/opt/<PluginName>` before removing the lock file entry, or `vim.pack` will restore it on next startup with a "Repaired corrupted lock data" warning.

## 7. Verification & Debugging

Always verify changes using these commands:

1. **Syntax Check**: `luac -p lua/**/*.lua` (Must pass with no errors).
2. **Headless Startup**: `nvim --headless +quit` (Must exit cleanly with code 0).
3. **Startup Benchmark**: `zig run eval_startuptime.zig` (Covers immediate + VimEnter + BufReadPre + UIEnter plugins via `doautocmd UIEnter`. Reports last-source clock from `--startuptime` log, excluding settle sleep. Thresholds: ≤50ms EXCELLENT, ≤80ms GOOD, ≤120ms FAIR, >120ms SLOW. Options: `--file`, `--iterations`, `--warmup`, `--settle`, `--top`).
4. **Loaded Modules**: Inside Neovim, run `:lua print(vim.inspect(require('core.pack').loaded()))` to see which modules have been initialized.
