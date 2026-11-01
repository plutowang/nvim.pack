-- Plugin declarations (vim.pack.add) + declarative loading registry (core.pack)

-- Install plugins but DO NOT add to runtimepath. The pack engine will call
-- :packadd <name> right before loading each plugin's module, keeping startup
-- to only catppuccin sourced on the first frame.
vim.pack.add({

  -- UI / Colorscheme
  { src = 'https://github.com/catppuccin/nvim', name = 'catppuccin' },

  -- Core utilities
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/nvim-tree/nvim-web-devicons',
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/nvim-neotest/nvim-nio',

  -- Editor helpers
  'https://github.com/folke/which-key.nvim',
  'https://github.com/NMAC427/guess-indent.nvim',
  'https://github.com/folke/todo-comments.nvim',

  -- LSP + Mason
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim',
  'https://github.com/folke/lazydev.nvim',

  -- Completion (blink.cmp v2 tracks main; the lock pins the exact rev)
  'https://github.com/saghen/blink.lib',
  { src = 'https://github.com/saghen/blink.cmp', version = 'main' },

  -- Formatting
  'https://github.com/stevearc/conform.nvim',

  -- Treesitter
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-context', version = 'master' },
  { src = 'https://github.com/nvim-treesitter/nvim-treesitter-textobjects', version = 'main' },

  -- Git
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/esmuellert/codediff.nvim',

  -- Editing enhancements
  'https://github.com/windwp/nvim-autopairs',
  'https://github.com/lukas-reineke/indent-blankline.nvim',
  'https://github.com/MagicDuck/grug-far.nvim',
  'https://github.com/HiPhish/rainbow-delimiters.nvim',
  'https://github.com/kylechui/nvim-surround',
  'https://github.com/Wansmer/treesj',

  -- Navigation
  'https://github.com/folke/flash.nvim',
  'https://github.com/chrisgrieser/nvim-spider',

  -- Debugging
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/leoluz/nvim-dap-go',
  'https://github.com/theHamsta/nvim-dap-virtual-text',

  -- Testing
  'https://github.com/nvim-neotest/neotest',
  'https://github.com/lawrence-laz/neotest-zig',
  'https://github.com/fredrikaverpil/neotest-golang',
  'https://github.com/mrcjkb/rustaceanvim',
  'https://github.com/nvim-neotest/neotest-jest',
  'https://github.com/marilari88/neotest-vitest',

  -- Diagnostics
  'https://github.com/folke/trouble.nvim',

  -- Database
  'https://github.com/kndndrj/nvim-dbee',

  -- Productivity
  -- (nvim-genghis and persistence.nvim replaced by native implementations in tools.lua and core/autocmds.lua)

  -- Language-specific
  'https://github.com/folke/snacks.nvim',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',

  -- Visual effects
  'https://github.com/catgoose/nvim-colorizer.lua',

  -- Statusline
  'https://github.com/rebelot/heirline.nvim',

  -- AI / OpenCode integration
  'https://github.com/nickjvandyke/opencode.nvim',

}, { confirm = false, load = function() end })

-- =============================================================================
-- Declarative loading registry
-- Each entry describes when and how to load a plugin module.
-- Fields:
--   mod     — module name under plugins/ (e.g. 'catppuccin' → plugins/catppuccin.lua)
--   event   — autocmd event (string or array) to trigger loading (once=true by default)
--   keys    — keymaps that trigger loading on first press; engine replays the key after
--   defer   — milliseconds to delay via vim.defer_fn
--   packadd — plugin directory names to :packadd before requiring the module
-- =============================================================================

local pack = require('core.pack')

pack.setup({

  -- -------------------------------------------------------------------------
  -- Immediate (first frame — keep minimal; only catppuccin)
  -- -------------------------------------------------------------------------
  { mod = 'catppuccin', packadd = { 'catppuccin' } },

  -- -------------------------------------------------------------------------
  -- VimEnter (non-blocking — loads after init but before UI renders)
  -- Snacks setup (picker/explorer/image) + native bigfile/lazygit/terminal keymaps
  -- -------------------------------------------------------------------------
  { mod = 'snacks', fn = 'setup', event = 'VimEnter', packadd = { 'snacks.nvim' } },
  { mod = 'ui', fn = 'native',    event = 'VimEnter' },
  { mod = 'ui', fn = 'bigfile',   event = 'VimEnter' },
  { mod = 'ui', fn = 'quickfile', event = 'VimEnter' },

  -- -------------------------------------------------------------------------
  -- UIEnter (non-blocking — loads after first frame renders)
  -- -------------------------------------------------------------------------
  -- { mod = 'lualine',    event = 'UIEnter', packadd = { 'lualine.nvim', 'nvim-web-devicons' } },
  { mod = 'heirline',   event = 'UIEnter', packadd = { 'heirline.nvim', 'nvim-web-devicons' } },
  { mod = 'ui',         fn = 'which_key', event = 'UIEnter', packadd = { 'which-key.nvim' } },
  -- Loaded 1ms after startup so the plugin is on the runtimepath and
  -- `:checkhealth opencode` resolves. Only keymaps are registered; no server is
  -- contacted because `require('opencode')` happens inside each callback.
  { mod = 'opencode',   fn = 'setup', defer = 1, packadd = { 'opencode.nvim' } },
  { mod = 'navigation', event = 'UIEnter', packadd = { 'flash.nvim', 'nvim-spider' } },
  { mod = 'editing',    fn = 'base_ui',    event = 'UIEnter', packadd = { 'indent-blankline.nvim', 'rainbow-delimiters.nvim' } },
  { mod = 'editing',    fn = 'autopairs',  event = { 'InsertEnter', 'CmdlineEnter' }, packadd = { 'nvim-autopairs' } },
  { mod = 'editing',    fn = 'surround',   keys = {
    { 'ys', mode = 'n', desc = 'Add Surround' },
    { 'cs', mode = 'n', desc = 'Change Surround' },
    { 'ds', mode = 'n', desc = 'Delete Surround' },
    { 'S',  mode = 'v', desc = 'Add Surround (Visual)' },
  }, packadd = { 'nvim-surround' } },
  { mod = 'editing',    fn = 'grug_far',   keys = {
    { '<leader>sR', desc = '[S]earch and [R]eplace' },
    { '<leader>sW', desc = '[S]earch and replace current [W]ord' },
  }, packadd = { 'grug-far.nvim' } },
  { mod = 'editing',    fn = 'treesj',     keys = {
    { 'gS', desc = 'Split node under cursor' },
    { 'gJ', desc = 'Join node under cursor' },
  }, packadd = { 'treesj' } },

  -- -------------------------------------------------------------------------
  -- BufReadPre / BufNewFile (core file-level features)
  -- -------------------------------------------------------------------------
  { mod = 'treesitter', fn = 'base',    event = { 'BufReadPre', 'BufNewFile' }, packadd = { 'nvim-treesitter' } },
  { mod = 'lsp',                        event = { 'BufReadPre', 'BufNewFile' }, packadd = { 'mason.nvim', 'mason-tool-installer.nvim', 'lazydev.nvim' } },
  { mod = 'lsp', fn = 'rustacean',      event = { 'BufReadPre', 'BufNewFile' }, pattern = { '*.rs' }, packadd = { 'rustaceanvim' } },
  { mod = 'git',        fn = 'signs',   event = { 'BufReadPre', 'BufNewFile' }, packadd = { 'gitsigns.nvim', 'plenary.nvim' } },
  { mod = 'treesitter', fn = 'context', event = { 'BufReadPre', 'BufNewFile' }, packadd = { 'nvim-treesitter-context', 'nvim-treesitter-textobjects' } },
  -- -------------------------------------------------------------------------
  -- InsertEnter / CmdlineEnter (completion)
  -- -------------------------------------------------------------------------
  { mod = 'completion', event = { 'InsertEnter', 'CmdlineEnter' }, packadd = { 'lazydev.nvim', 'blink.lib', 'blink.cmp' } },

  -- -------------------------------------------------------------------------
  -- BufWritePre (formatting on save — conform has its own internal guard)
  -- -------------------------------------------------------------------------
  { mod = 'editing', fn = 'format', event = 'BufWritePre', packadd = { 'conform.nvim' } },

  -- -------------------------------------------------------------------------
  -- Keymap-triggered (first keypress loads the module, then replays the key)
  -- -------------------------------------------------------------------------

  { mod = 'debugging', keys = {
      { '<F5>',   desc = 'Debug Continue' },
      { '<F1>',   desc = 'Debug Step Into' },
      { '<F2>',   desc = 'Debug Step Over' },
      { '<F3>',   desc = 'Debug Step Out' },
      { '<F7>',   desc = 'Debug UI' },
      { '<leader>db',    desc = 'Debug Breakpoint' },
      { '<leader>dB',    desc = 'Debug Conditional BP' },
      { '<leader>dx',    desc = 'Debug Clear BPs' },
      { '<leader>dC',    desc = 'Debug Run to Cursor' },
      { '<leader>dl',    desc = 'Debug Run Last' },
      { '<leader>dt',    desc = 'Debug Terminate' },
      { '<leader>dp',    desc = 'Debug Pause' },
      { '<leader>dv',    desc = 'Debug Hover Toggle' },
      { '<leader>dr',    desc = 'Debug REPL Eval' },
      { '<leader>dfc',   desc = 'Debug Continue' },
      { '<leader>dfi',   desc = 'Debug Step Into' },
      { '<leader>dfO',   desc = 'Debug Step Over' },
      { '<leader>dfo',   desc = 'Debug Step Out' },
      { '<leader>dfu',   desc = 'Debug UI Toggle' },
      { '<leader>dir',   desc = 'Debug REPL' },
      { '<leader>dis',   desc = 'Debug Session' },
      { '<leader>diw',   desc = 'Debug Widget Hover' },
      { '<leader>diW',   desc = 'Debug Widget Scopes' },
      { '<leader>diE',   desc = 'Debug Eval', mode = { 'n', 'v' } },
      { '<leader>dgt',   desc = 'Debug Go Test' },
      { '<leader>dgl',   desc = 'Debug Go Last Test' },
    }, packadd = { 'nvim-dap', 'nvim-dap-ui', 'nvim-nio', 'nvim-dap-go', 'nvim-dap-virtual-text', 'mason-nvim-dap.nvim' } },

  { mod = 'tools', fn = 'testing', keys = {
      { '<leader>rt',   desc = 'Run Nearest Test' },
      { '<leader>rf',   desc = 'Run File Tests' },
      { '<leader>ra',   desc = 'Run All Tests' },
      { '<leader>rl',   desc = 'Run Last Test' },
      { '<leader>rs',   desc = 'Run Stop' },
      { '<leader>rS',   desc = 'Run Toggle Summary' },
      { '<leader>ro',   desc = 'Run Output Show' },
      { '<leader>rO',   desc = 'Run Toggle Output Panel' },
      { '<leader>rC',   desc = 'Run Clear Output Panel' },
      { '<leader>rw',   desc = 'Run Watch Toggle' },
    }, packadd = { 'neotest', 'nvim-nio', 'plenary.nvim', 'neotest-zig', 'neotest-golang', 'rustaceanvim', 'neotest-jest', 'neotest-vitest' } },

  { mod = 'tools', fn = 'database', keys = {
      { '<leader>Dt',   desc = 'DB Toggle UI' },
      { '<leader>Dc',   desc = 'DB Close' },
      { '<leader>De',   desc = 'DB Execute Query' },
    }, packadd = { 'nvim-dbee', 'nui.nvim' } },

  { mod = 'git', fn = 'diff', keys = {
      { '<leader>hd',   desc = 'Git Diff against index' },
      { '<leader>hD',   desc = 'Git Diff Last Commit' },
    }, packadd = { 'codediff.nvim' } },

  { mod = 'tools', fn = 'diagnostics', keys = {
      { '<leader>xx',   desc = 'Diagnostics (Trouble)' },
      { '<leader>xs',   desc = 'Symbols (Trouble)' },
      { '<leader>xQ',   desc = 'Quickfix List (Trouble)' },
    }, packadd = { 'trouble.nvim' } },

  { mod = 'tools', fn = 'productivity', keys = {
      { '<leader>uu',   desc = '[U]ndotree Toggle' },
      { '<leader>us',   desc = 'Session Restore' },
      { '<leader>ud',   desc = "Don't Save Session" },
      { '<leader>fr',   desc = 'File Rename' },
      { '<leader>fd',   desc = 'File Duplicate' },
      { '<leader>fn',   desc = 'File New' },
      { '<leader>fx',   desc = 'File Move' },
      { '<leader>fc',   desc = 'File Copy Path' },
      { '<leader>fy',   desc = 'File Copy Relative Path' },
    }, packadd = { 'nvim.undotree' } },

  -- -------------------------------------------------------------------------
  -- Deferred (idle — load after defer ms)
  -- -------------------------------------------------------------------------
  { mod = 'deferred', fn = 'markdown',      defer = 1,  packadd = { 'render-markdown.nvim' } },
  { mod = 'deferred', fn = 'images',        event = { 'BufReadPre', 'BufNewFile' }, pattern = { '*.md', '*.markdown' }, packadd = { 'snacks.nvim' } },
  { mod = 'deferred', fn = 'colorizer',     defer = 1,  packadd = { 'nvim-colorizer.lua' } },
  { mod = 'deferred', fn = 'guess_indent',  defer = 1,  packadd = { 'guess-indent.nvim' } },
  { mod = 'deferred', fn = 'todo_comments', defer = 1,  packadd = { 'todo-comments.nvim', 'plenary.nvim' } },

})
