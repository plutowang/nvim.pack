local M = {}

function M.signs()
  -- gitsigns.nvim
  local gitsigns = require('gitsigns')

  gitsigns.setup({
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation: ]c and [c are special — they work in diff mode too
      map('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal({ ']c', bang = true })
        else
          gitsigns.nav_hunk('next')
        end
      end, { desc = 'Jump to next git [c]hange' })

      map('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal({ '[c', bang = true })
        else
          gitsigns.nav_hunk('prev')
        end
      end, { desc = 'Jump to previous git [c]hange' })

      -- Actions (visual mode)
      map('v', '<leader>hs', function()
        gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
      end, { desc = 'Git [s]tage hunk' })
      map('v', '<leader>hr', function()
        gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
      end, { desc = 'Git [r]eset hunk' })

      -- Actions (normal mode)
      map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'Git [s]tage hunk' })
      map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'Git [r]eset hunk' })
      map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'Git [S]tage buffer' })
      map('n', '<leader>hu', gitsigns.undo_stage_hunk, { desc = 'Git [u]ndo stage hunk' })
      map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'Git [R]eset buffer' })
      map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'Git [p]review hunk' })
      map('n', '<leader>hb', gitsigns.blame_line, { desc = 'Git [b]lame line' })

      -- Toggles
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
      map('n', '<leader>tD', gitsigns.toggle_deleted, { desc = '[T]oggle git show [D]eleted' })
    end,
  })
end

function M.diff()
  -- diffview.nvim
  local diffview = require('diffview')

  diffview.setup({
    diff_binaries = false,
    enhanced_diff_hl = true,
    use_per_buffer_settings = 'only',
    show_help_hints = true,
    hooks = {
      diff_buf_read = function(bufnr)
        vim.keymap.set('n', 'q', ':DiffviewClose<CR>', { buffer = bufnr, desc = 'Close diffview' })
        vim.keymap.set('n', '<leader>q', ':DiffviewClose<CR>', { buffer = bufnr, desc = 'Close diffview' })
      end,
    },
    keymaps = {
      disable_defaults = false,
      view = {
        ['<leader>q'] = ':DiffviewClose<CR>',
        ['q'] = ':DiffviewClose<CR>',
      },
      diff_builder = {
        [']c'] = function() diffview.nav_hunk('next') end,
        ['[c'] = function() diffview.nav_hunk('prev') end,
      },
    },
    defaults = {
      view = {
        default = {
          layout = 'diff3_mixed',
        },
      },
      file_history = {
        layout = 'diff3_mixed',
      },
    },
  })

  vim.opt.fillchars:append({ diff = "░" })

  -- Keybindings for opening diffs
  vim.keymap.set('n', '<leader>hd', function()
    vim.cmd('DiffviewOpen')
  end, { desc = 'Git [d]iff against index' })

  vim.keymap.set('n', '<leader>hD', function()
    vim.cmd('DiffviewOpen HEAD^')
  end, { desc = 'Git [D]iff against last commit' })

  vim.keymap.set('n', '<leader>hm', function()
    vim.cmd('DiffviewOpen --conflict')
  end, { desc = 'Git [m]erge conflict' })
end

return M