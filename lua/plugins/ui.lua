local M = {}

function M.which_key()
  require('which-key').setup {
    delay = 200,
    icons = {
      mappings = vim.g.have_nerd_font,
      keys = vim.g.have_nerd_font and {} or {
        Up = '<Up> ', Down = '<Down> ', Left = '<Left> ', Right = '<Right> ',
        C = '<C-…> ', M = '<M-…> ', D = '<D-…> ', S = '<S-…> ',
        CR = '<CR> ', Esc = '<Esc> ',
        ScrollWheelDown = '<ScrollWheelDown> ', ScrollWheelUp = '<ScrollWheelUp> ',
        NL = '<NL> ', BS = '<BS> ', Space = '<Space> ', Tab = '<Tab> ',
        F1 = '<F1>', F2 = '<F2>', F3 = '<F3>', F4 = '<F4>',
        F5 = '<F5>', F6 = '<F6>', F7 = '<F7>', F8 = '<F8>',
        F9 = '<F9>', F10 = '<F10>', F11 = '<F11>', F12 = '<F12>',
      },
    },
    spec = {
      { '<leader>s', group = '[S]earch' },
      { '<leader>e', group = '[E]xplorer' },
      { '<leader>g', group = '[G]it' },
      { '<leader>h', group = '[G]it [H]unk', mode = { 'n', 'v' } },
      { '<leader>r', group = '[R]un/Test' },
      { '<leader>d', group = '[D]ebug' },
      { '<leader>df', group = '[D]ebug [F]-key' },
      { '<leader>di', group = '[D]ebug [I]nspection' },
      { '<leader>dg', group = '[D]ebug [G]o' },
      { '<leader>D', group = '[D]atabase' },
      { '<leader>x', group = 'Trouble/[X]' },
      { '<leader>t', group = '[T]erminal/Toggle', mode = { 'n', 'v' } },
      { '<leader>w', group = 'S[w]ap/Wrap' },
      { '<leader>b', group = '[B]uffer' },
      { '<leader>n', group = '[N]o/Clear' },
      { '<leader>u', group = '[U]tility/Settings' },
      { '<leader>f', group = '[F]ile' },
      { 'gr', group = 'LSP Actions' },
      { ']', group = 'Next' },
      { '[', group = 'Previous' },
      -- Hidden shortcuts
      { '<leader>1', hidden = true },
      { '<leader>2', hidden = true },
      { '<leader>3', hidden = true },
      { '<leader>4', hidden = true },
      { '<leader>5', hidden = true },
      { '<leader>6', hidden = true },
      { '<leader>7', hidden = true },
      { '<leader>8', hidden = true },
      { '<leader>9', hidden = true },
      { '<leader>0', hidden = true },
    },
  }
end

function M.snacks()
  -- Native replacements for snacks.nvim features
  -- bigfile and quickfile are loaded via separate VimEnter registry entries.
  local native = require('core.native')

  -- Git operations
  vim.keymap.set('n', '<leader>gb', native.gitbrowse,            { desc = '[G]it [b]rowse' })
  vim.keymap.set('n', '<leader>gl', native.lazygit_log,          { desc = '[G]it [L]og' })
  vim.keymap.set('n', '<leader>gg', native.lazygit,              { desc = 'Lazy [G]it' })

  -- Buffer operations
  vim.keymap.set('n', '<leader>bd', native.bufdelete,            { desc = '[B]uffer [D]elete' })
  vim.keymap.set('n', '<leader>bD', native.bufdelete_force,      { desc = '[B]uffer [D]elete Force' })
  vim.keymap.set('n', '<leader>bO', native.bufdelete_other,      { desc = '[B]uffer Delete [O]thers' })
  vim.keymap.set('n', '<leader>ba', native.bufdelete_all,        { desc = '[B]uffer Delete [A]ll' })

  -- Terminal operations
  vim.keymap.set('n', '<leader>tf', native.terminal_float,       { desc = '[T]erminal [F]loat' })
  vim.keymap.set('n', '<leader>tp', function() native.terminal_repl('python3') end, { desc = '[T]erminal [P]ython REPL' })
  vim.keymap.set('n', '<leader>to', function() native.terminal_repl('node') end,    { desc = '[T]erminal N[o]de REPL' })
  vim.keymap.set('n', '<leader>ts', native.scratch,              { desc = '[T]erminal [S]cratch Buffer' })
  vim.keymap.set({ 'n', 'v' }, '<leader>tS', native.scratch_select, { desc = '[T]oggle [S]elect Scratch Buffer' })
end

function M.bigfile()
  -- Disable expensive features for files larger than 1.5 MB
  local BIGFILE_SIZE = 1.5 * 1024 * 1024
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = vim.api.nvim_create_augroup('nvimpack-bigfile', { clear = true }),
    callback = function(ev)
      local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ev.buf))
      if not ok or not stat or stat.size <= BIGFILE_SIZE then return end
      vim.b[ev.buf].bigfile = true
      -- Disable treesitter highlighting
      vim.bo[ev.buf].syntax = 'off'
      vim.treesitter.stop(ev.buf)
      -- Disable folding
      vim.wo.foldmethod = 'manual'
      vim.wo.foldexpr   = ''
      -- Disable swapfile for huge files
      vim.bo[ev.buf].swapfile = false
      vim.notify(
        ('Big file (%.1f MB) — treesitter/folding disabled'):format(stat.size / 1024 / 1024),
        vim.log.levels.WARN
      )
    end,
  })
end

function M.quickfile()
  -- Defer plugin loading until after the first buffer is fully read in,
  -- ensuring the initial file renders instantly with syntax alone.
  -- (This is a no-op for startup; just signals the feature is "enabled".)
  -- The real effect is the absence of any blocking BufReadPost work here.
end

return M