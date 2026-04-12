-- =============================================================================
-- Core Autocommands
-- Includes: highlight-on-yank, auto-save, session management,
--           build hooks (PackChanged), LSP log rotation
-- =============================================================================

-- =============================================================================
-- HIGHLIGHT ON YANK
-- =============================================================================
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('nvimpack-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- =============================================================================
-- AUTO-SAVE (replaces auto-save.nvim)
-- Immediate save on BufLeave/FocusLost; debounced 3s save on text change.
-- =============================================================================

local _save_timer = nil
local _autosave_group = vim.api.nvim_create_augroup('nvimpack-autosave', { clear = true })

local function cancel_debounce()
  if _save_timer then
    _save_timer:stop()
    _save_timer:close()
    _save_timer = nil
  end
end

local function is_saveable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.bo[bufnr].modifiable
    and not vim.bo[bufnr].readonly
    and vim.bo[bufnr].buftype == ''
    and vim.bo[bufnr].modified
end

vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
  desc = 'Auto-save with 3s debounce',
  group = _autosave_group,
  callback = function()
    if not is_saveable() then return end
    cancel_debounce()
    _save_timer = vim.uv.new_timer()
    _save_timer:start(3000, 0, vim.schedule_wrap(function()
      cancel_debounce()
      if is_saveable() then
        vim.cmd('silent! write')
      end
    end))
  end,
})

vim.api.nvim_create_autocmd('InsertEnter', {
  desc = 'Cancel deferred auto-save when entering insert mode',
  group = _autosave_group,
  callback = cancel_debounce,
})

vim.api.nvim_create_autocmd({ 'BufLeave', 'FocusLost' }, {
  desc = 'Immediate auto-save on focus/buffer leave',
  group = _autosave_group,
  callback = function()
    cancel_debounce()
    if is_saveable() then
      vim.cmd('silent! write')
    end
  end,
})

-- =============================================================================
-- SESSION MANAGEMENT (replaces persistence.nvim)
-- Saves session to stdpath('data')/sessions/ on exit; loads on demand.
-- =============================================================================

local _session_dir = vim.fn.stdpath('data') .. '/sessions'
vim.fn.mkdir(_session_dir, 'p')

-- Expose session dir for keymaps in tools.lua
vim.g._native_session_dir = _session_dir

local _session_save_enabled = true
local _session_group = vim.api.nvim_create_augroup('nvimpack-session', { clear = true })

vim.api.nvim_create_autocmd('VimLeavePre', {
  desc = 'Auto-save session on exit',
  group = _session_group,
  callback = function()
    if not _session_save_enabled then return end
    -- Only save if Neovim was opened without file arguments
    if #vim.fn.argv() == 0 then
      local session_file = _session_dir .. '/last.vim'
      pcall(vim.cmd, 'mksession! ' .. vim.fn.fnameescape(session_file))
    end
  end,
})

-- Expose session control for keymap callbacks
function vim.g._session_disable()
  _session_save_enabled = false
  -- Clear the autocmd so the current session is not saved
  vim.api.nvim_create_augroup('nvimpack-session', { clear = true })
  vim.notify('Session auto-save disabled for this session', vim.log.levels.INFO)
end

-- =============================================================================
-- BUILD HOOKS (PackChanged)
-- Run after vim.pack installs/updates a plugin.
-- Uses ev.data.spec.name, ev.data.kind, and ev.data.path directly per the
-- official vim.pack API — no glob path searching needed.
-- =============================================================================

vim.api.nvim_create_autocmd('PackChanged', {
  desc = 'Run build steps after plugin install/update',
  callback = function(ev)
    local name = ev.data.spec.name
    local kind = ev.data.kind  -- 'install' | 'update' | 'delete'
    local path = ev.data.path  -- absolute path to the plugin directory

    if kind ~= 'install' and kind ~= 'update' then
      return
    end

    -- telescope-fzf-native: compile the native sorter
    if name == 'telescope-fzf-native.nvim' then
      vim.system({ 'make' }, { cwd = path }, function(result)
        if result.code ~= 0 then
          vim.schedule(function()
            vim.notify('telescope-fzf-native build failed:\n' .. (result.stderr or ''), vim.log.levels.ERROR)
          end)
        else
          vim.schedule(function()
            vim.notify('telescope-fzf-native built successfully', vim.log.levels.INFO)
          end)
        end
      end)
    end

    -- nvim-treesitter: run :TSUpdate after install/update
    if name == 'nvim-treesitter' then
      vim.schedule(function()
        local ok, _ = pcall(vim.cmd, 'TSUpdate')
        if not ok then
          vim.notify('TSUpdate failed — run :TSUpdate manually.', vim.log.levels.WARN)
        end
      end)
    end

    -- nvim-dbee: install the Go binary
    if name == 'nvim-dbee' then
      vim.schedule(function()
        local ok, dbee = pcall(require, 'dbee')
        if ok then
          dbee.install()
          vim.notify('nvim-dbee binary installed', vim.log.levels.INFO)
        else
          vim.notify('nvim-dbee not loaded yet — run :lua require("dbee").install() manually', vim.log.levels.WARN)
        end
      end)
    end

    -- blink.cmp: compile Rust fuzzy matching library
    if name == 'blink.cmp' then
      if vim.fn.executable('cargo') == 0 then
        return
      end
      vim.system({ 'cargo', 'build', '--release' }, { cwd = path }, function(result)
        if result.code ~= 0 then
          vim.schedule(function()
            vim.notify('blink.cmp Rust build failed:\n' .. (result.stderr or ''), vim.log.levels.ERROR)
          end)
        else
          vim.schedule(function()
            vim.notify('blink.cmp Rust fuzzy library built successfully', vim.log.levels.INFO)
          end)
        end
      end)
    end
  end,
})

-- =============================================================================
-- LSP LOG ROTATION
-- Truncate the LSP log file on VimEnter if it exceeds 10 MB to prevent
-- unbounded growth (the default log level is WARN, which still accumulates).
-- The log is recreated automatically when LSP clients start.
-- =============================================================================
vim.api.nvim_create_autocmd('VimEnter', {
  desc = 'Truncate oversized LSP log file',
  group = vim.api.nvim_create_augroup('nvimpack-lsp-log-rotation', { clear = true }),
  callback = function()
    local log_path = vim.lsp.log.get_filename()
    if not log_path then return end
    local ok, stat = pcall(vim.uv.fs_stat, log_path)
    if ok and stat and stat.size > 10 * 1024 * 1024 then
      pcall(vim.uv.fs_unlink, log_path)
    end
  end,
})
