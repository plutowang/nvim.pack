local M = {}

function M.signs()
  -- gitsigns.nvim
  local gitsigns = require('gitsigns')

  gitsigns.setup({
    signs = {
      add = { text = '╎' },
      change = { text = '╎' },
      delete = { text = '╴' },
      topdelete = { text = '▔' },
      changedelete = { text = '╎' },
      untracked = { text = '┆' },
    },
    on_attach = function(bufnr)
      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buf = bufnr
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
      end, { desc = 'Git [s]tage/[u]nstage hunk' })
      map('v', '<leader>hr', function()
        gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
      end, { desc = 'Git [r]eset hunk' })

      -- Actions (normal mode)
      -- stage_hunk toggles: on a staged sign it unstages, so no separate undo map.
      map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'Git [s]tage/[u]nstage hunk' })
      map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'Git [r]eset hunk' })
      map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'Git [S]tage buffer' })
      map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'Git [R]eset buffer' })
      map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'Git [p]review hunk' })
      map('n', '<leader>hb', gitsigns.blame_line, { desc = 'Git [b]lame line' })

      -- Toggles
      map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle git show [b]lame line' })
    end,
  })
end

function M.diff()
  -- diffview.nvim: file-panel diff viewer with merge tool and file history.
  -- Current API: layouts live under `view.*`; `use_per_buffer_settings`,
  -- `diffview.nav_hunk` and `:DiffviewOpen --conflict` no longer exist.
  -- Kept inside this function: the `git.signs` entry does not :packadd diffview.
  require('diffview').setup({
    enhanced_diff_hl = true,
    view = {
      default = { layout = 'diff2_horizontal' },
      merge_tool = { layout = 'diff3_mixed' },
      file_history = { layout = 'diff2_horizontal' },
    },
    hooks = {
      -- Global 'list'/'wrap' are on (core/options.lua); both add noise here.
      diff_buf_read = function()
        vim.opt_local.wrap = false
        vim.opt_local.list = false
      end,
    },
    keymaps = {
      -- `q` closes only the help/option panels by default; in these contexts it is
      -- unbound, so `q` would start a macro recording. Close the whole view instead.
      view               = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } } },
      file_panel         = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } } },
      file_history_panel = { { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close diffview' } } },
    },
  })

  vim.opt.fillchars:append({ diff = '░' })

  vim.keymap.set('n', '<leader>hd', '<cmd>DiffviewOpen<cr>', { desc = 'Git [d]iff against index' })
  vim.keymap.set('n', '<leader>hD', '<cmd>DiffviewOpen HEAD~1<cr>', { desc = 'Git [D]iff against last commit' })
  vim.keymap.set('n', '<leader>hH', '<cmd>DiffviewFileHistory %<cr>', { desc = 'Git [H]istory of current file' })

  -- Fetch first so "origin/main" means the latest remote tip, then diff from the
  -- merge-base to HEAD (triple-dot): what this branch changed, without showing
  -- main's own new commits as reversals. Async, so the editor never blocks.
  vim.keymap.set('n', '<leader>hm', function()
    vim.system({ 'git', 'fetch', '--quiet', 'origin', 'main' }, { text = true }, function(out)
      vim.schedule(function()
        if out.code ~= 0 then
          local err = vim.trim(out.stderr or '')
          vim.notify(
            'git fetch origin main failed: ' .. (err ~= '' and err or 'unknown error'),
            vim.log.levels.ERROR
          )
          return
        end
        vim.cmd('DiffviewOpen origin/main...HEAD')
      end)
    end)
  end, { desc = 'Git diff vs latest origin/[m]ain' })
end

return M
