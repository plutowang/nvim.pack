-- Telescope fuzzy finder

local M = {}

--- Load ui-select early (on UIEnter) so vim.ui.select is overridden before
--- LSP keymaps like `gra` fire. Full telescope setup happens on first keypress.
function M.ui_select()
  require('telescope').setup {
    defaults = {
      preview = {
        treesitter = true,
      },
    },
    extensions = {
      ['ui-select'] = {
        require('telescope.themes').get_dropdown(),
      },
    },
  }
  pcall(require('telescope').load_extension, 'ui-select')
end

--- Full telescope setup: fzf extension + keymaps. Triggered on first <leader>s* keypress.
function M.setup()
  -- Load fzf extension (setup already done in M.ui_select, but idempotent)
  pcall(require('telescope').load_extension, 'fzf')

  -- Custom Multi-Grep function
  local function live_multigrep(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or (vim.uv or vim.loop).cwd()

    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local make_entry = require('telescope.make_entry')
    local conf = require('telescope.config').values

    local finder = finders.new_async_job {
      command_generator = function(prompt)
        if not prompt or prompt == '' then
          return nil
        end

        local pieces = vim.split(prompt, '  ')
        local args = { 'rg' }

        if opts.no_regex then
          table.insert(args, '--fixed-strings')
        end

        if pieces[1] then
          table.insert(args, '-e')
          table.insert(args, pieces[1])
        end

        if pieces[2] then
          table.insert(args, '-g')
          table.insert(args, pieces[2])
        end

        return vim.iter({
          args,
          { '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case' },
        }):flatten():totable()
      end,
      entry_maker = make_entry.gen_from_vimgrep(opts),
      cwd = opts.cwd,
    }

    pickers.new(opts, {
      debounce = 100,
      prompt_title = opts.prompt_title or 'Multi Grep',
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = require('telescope.sorters').empty(),
    }):find()
  end

  -- Keymaps
  vim.keymap.set('n', '<leader>sh', function() require('telescope.builtin').help_tags() end, { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', function() require('telescope.builtin').keymaps() end, { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', function() require('telescope.builtin').find_files() end, { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', function() require('telescope.builtin').builtin() end, { desc = '[S]earch [S]elect Telescope' })
  vim.keymap.set('n', '<leader>sw', function() require('telescope.builtin').grep_string() end, { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sd', function() require('telescope.builtin').diagnostics() end, { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', function() require('telescope.builtin').resume() end, { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', function() require('telescope.builtin').oldfiles() end, { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader><leader>', function() require('telescope.builtin').buffers() end, { desc = '[ ] Find existing buffers' })

  vim.keymap.set('n', '<leader>sg', live_multigrep, { desc = '[S]earch by [G]rep' })
  vim.keymap.set('n', '<leader>sG', function()
    live_multigrep { no_regex = true, prompt_title = 'Multi Grep (Literal)' }
  end, { desc = '[S]earch by [G]rep (literal)' })

  vim.keymap.set('n', '<leader>/', function()
    require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = '[/] Fuzzily search in current buffer' })

  vim.keymap.set('n', '<leader>s/', function()
    require('telescope.builtin').live_grep {
      grep_open_files = true,
      prompt_title = 'Live Grep in Open Files',
    }
  end, { desc = '[S]earch [/] in Open Files' })

  vim.keymap.set('n', '<leader>sn', function()
    require('telescope.builtin').find_files { cwd = vim.fn.stdpath('config') }
  end, { desc = '[S]earch [N]eovim files' })
end

return M
