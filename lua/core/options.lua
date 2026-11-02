-- =============================================================================
-- Core Options
-- =============================================================================

-- Aggressively disable unused providers
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python_provider = 0

-- Disable unused built-in plugins for startup speed
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1

-- Nerd Font availability flag (used by plugins)
vim.g.have_nerd_font = true

-- =============================================================================
-- Display
-- =============================================================================
vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.showmode = false
vim.o.cursorline = true
vim.o.signcolumn = 'yes'
vim.o.termguicolors = true
vim.o.laststatus = 3
vim.opt.pumblend = 20
vim.opt.winblend = 20
vim.opt.smoothscroll = true
-- 0.12+ features; has() is a floor, so this remains active on 0.13+.
if vim.fn.has('nvim-0.12') == 1 then
  pcall(function() vim.o.winborder = 'rounded' end)
  pcall(function() vim.o.pumborder = 'rounded' end)
end

-- =============================================================================
-- Editing
-- =============================================================================
vim.o.clipboard = 'unnamedplus'
vim.o.breakindent = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = 'split'
vim.o.confirm = true
vim.o.scrolloff = 10
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.wrap = true
vim.o.sidescrolloff = 8
vim.o.gdefault = true  -- global replace by default

-- =============================================================================
-- Performance
-- =============================================================================
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.opt.ttimeoutlen = 10
vim.opt.lazyredraw = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.shortmess:append 'c'
vim.opt.synmaxcol = 500
vim.opt.regexpengine = 0  -- auto-select best regex engine

-- =============================================================================
-- Files & History
-- =============================================================================
vim.o.undofile = true
vim.opt.undolevels = 10000
vim.opt.history = 1000
vim.opt.hidden = true

-- =============================================================================
-- Splits
-- =============================================================================
vim.o.splitright = true
vim.o.splitbelow = true

-- =============================================================================
-- Folding
-- =============================================================================
vim.o.foldmethod = 'expr'
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
if vim.fn.has('nvim-0.12') == 1 then
  vim.opt.foldtext = ''
end
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.opt.foldnestmax = 3

-- =============================================================================
-- Diff
-- =============================================================================
if vim.fn.has('nvim-0.12') == 1 then
  vim.opt.diffopt = {
    'internal',
    'filler',
    'closeoff',
    'indent-heuristic',
    'inline:word',
    'algorithm:histogram',
    'linematch:40',
  }
end

-- =============================================================================
-- Completion
-- =============================================================================
vim.opt.pumheight = 15
vim.opt.pumwidth = 30
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

-- =============================================================================
-- Filetype detection patches
-- =============================================================================
vim.filetype.add {
  pattern = {
    ['.*/.*%.component%.html'] = 'htmlangular',
  },
}

-- =============================================================================
-- Minimal chrome for all floating windows
-- Borders come from 'winborder' or the plugin's explicit border.
-- =============================================================================
local orig_open_win = vim.api.nvim_open_win
vim.api.nvim_open_win = function(buffer, enter, config)
  if config and config.relative and not config.style then
    config.style = 'minimal'
  end
  return orig_open_win(buffer, enter, config)
end

local ui2_active = false
if vim.fn.has('nvim-0.12') == 1 then
  local function enable_ui2()
    local ok = pcall(function()
      require('vim._core.ui2').enable()
    end)
    ui2_active = ok and #vim.api.nvim_list_uis() > 0
    return ui2_active
  end

  local function set_cmdheight()
    if ui2_active then vim.o.cmdheight = 0 end
  end

  ui2_active = enable_ui2()
  if not ui2_active then
    vim.api.nvim_create_autocmd('UIEnter', {
      once = true,
      callback = function()
        if enable_ui2() then set_cmdheight() end
      end,
    })
  end
  set_cmdheight()
  -- 'cmdheight' is local to the tabpage; re-apply on tab switches.
  vim.api.nvim_create_autocmd('TabEnter', { callback = set_cmdheight })
end
