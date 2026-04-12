local M = {}

function M.testing()
  -- neotest + adapters
  require('neotest').setup({
    adapters = {
      require('neotest-zig')({
        dap = {
          adapter = 'lldb',
        },
      }),
      require('neotest-golang')({
        extra_args = { '-count=1' },
        warn_test_name_dupes = false,
      }),
      require('neotest-jest')({
        jestCommand = 'pnpm test --',
        jestConfigFile = function(file)
          local pkg = file:match('(.*/[^/]+/)src')
          if pkg then
            return pkg .. 'jest.config.ts'
          end
          return vim.fn.getcwd() .. '/jest.config.ts'
        end,
        cwd = function(file)
          local pkg = file:match('(.*/[^/]+/)src')
          return pkg or vim.fn.getcwd()
        end,
        env = { CI = true },
      }),
      require('neotest-vitest')({
        vitestCommand = 'pnpm vitest',
        cwd = function(_file)
          return vim.fn.getcwd()
        end,
        env = { CI = true },
      }),
      require('rustaceanvim.neotest'),
    },
    status = { virtual_text = true },
    output = { open_on_run = true, close_on_exit = true },
    quickfix = {
      open = function()
        vim.cmd('copen 10')
      end,
    },
    discovery = { enabled = true },
    diagnostic = { enabled = true },
  })

  -- Keymaps
  vim.keymap.set('n', '<leader>rt', function() require('neotest').run.run() end, { desc = '[R]un Nearest [T]est' })
  vim.keymap.set('n', '<leader>rf', function() require('neotest').run.run(vim.fn.expand('%')) end, { desc = '[R]un [F]ile tests' })
  vim.keymap.set('n', '<leader>ra', function() require('neotest').run.run(vim.uv.cwd()) end, { desc = '[R]un [A]ll tests' })
  vim.keymap.set('n', '<leader>rl', function() require('neotest').run.run_last() end, { desc = '[R]un [L]ast test' })
  vim.keymap.set('n', '<leader>rs', function() require('neotest').run.stop() end, { desc = '[R]un [S]top' })
  vim.keymap.set('n', '<leader>rS', function() require('neotest').summary.toggle() end, { desc = '[R]un Toggle [S]ummary' })
  vim.keymap.set('n', '<leader>ro', function() require('neotest').output.open({ enter = true, auto_close = true }) end, { desc = '[R]un [O]utput show' })
  vim.keymap.set('n', '<leader>rO', function() require('neotest').output_panel.toggle() end, { desc = '[R]un Toggle [O]utput Panel' })
  vim.keymap.set('n', '<leader>rC', function() require('neotest').output_panel.clear() end, { desc = '[R]un [C]lear Output Panel' })
  vim.keymap.set('n', '<leader>rw', function() require('neotest').watch.toggle(vim.fn.expand('%')) end, { desc = '[R]un [W]atch toggle' })
end

function M.database()
  -- nvim-dbee
  local db_url = vim.fn.getenv('DB')
  if db_url == vim.NIL or db_url == '' then
    db_url = vim.fn.getenv('DATABASE')
  end
  if db_url == vim.NIL or db_url == '' then
    db_url = vim.fn.getenv('POSTGRES')
  end

  local sources = {}

  if db_url ~= vim.NIL and db_url ~= '' then
    local db_type = db_url:match('^(%w+)://')
    local type_map = {
      postgresql = 'postgres',
      postgres = 'postgres',
      mysql = 'mysql',
      sqlite = 'sqlite',
      sqlserver = 'sqlserver',
      mssql = 'sqlserver',
      mongodb = 'mongo',
      mongo = 'mongo',
      redis = 'redis',
    }
    local connection_type = type_map[db_type] or db_type

    table.insert(
      sources,
      require('dbee.sources').MemorySource:new({
        {
          name = 'default',
          type = connection_type,
          url = db_url,
        },
      })
    )
  end

  require('dbee').setup({
    sources = sources,
  })

  -- Keymaps
  vim.keymap.set('n', '<leader>Dt', function()
    require('dbee').toggle()
  end, { desc = '[D]atabase [T]oggle UI' })

  vim.keymap.set('n', '<leader>Dc', function()
    require('dbee').close()
  end, { desc = '[D]atabase [C]lose' })

  vim.keymap.set('n', '<leader>De', function()
    require('dbee').execute()
  end, { desc = '[D]atabase [E]xecute Query' })
end

function M.diagnostics()
  -- trouble.nvim
  require('trouble').setup({
    modes = {
      preview_float = {
        mode = 'diagnostics',
        preview = {
          type = 'float',
          relative = 'editor',
          border = 'rounded',
          title = 'Preview',
          title_pos = 'center',
          position = { 0, -2 },
          size = { width = 0.3, height = 0.3 },
          zindex = 200,
        },
      },
    },
    icons = {
      indent = {
        middle = ' ',
        last = ' ',
        top = ' ',
        ws = '│  ',
      },
    },
    focus = false,
    follow = true,
    restore = true,
    multiline = true,
    indent_lines = true,
    win_config = {
      border = 'single',
    },
    auto_open = false,
    auto_close = false,
    auto_preview = true,
    auto_fold = false,
    auto_jump = { 'lsp_definitions' },
    use_diagnostic_signs = true,
  })

  -- Keymaps
  vim.keymap.set('n', '<leader>xx', function()
    vim.cmd('Trouble diagnostics toggle')
  end, { desc = 'Diagnostics (Trouble)' })

  vim.keymap.set('n', '<leader>xs', function()
    vim.cmd('Trouble symbols toggle focus=false')
  end, { desc = 'Symbols (Trouble)' })

  vim.keymap.set('n', '<leader>xQ', function()
    vim.cmd('Trouble qflist toggle')
  end, { desc = 'Quickfix List (Trouble)' })
end

function M.productivity()
  -- undotree settings
  vim.g.undotree_WindowLayout = 2
  vim.g.undotree_SplitWidth = 30
  vim.g.undotree_SetFocusWhenToggle = 1

  -- Native file operations (replaces nvim-genghis)
  vim.keymap.set('n', '<leader>fr', function()
    local old = vim.fn.expand('%:p')
    local old_rel = vim.fn.expand('%:t')
    vim.ui.input({ prompt = 'Rename to: ', default = old_rel }, function(new_name)
      if not new_name or new_name == '' or new_name == old_rel then return end
      local new_path = vim.fn.expand('%:p:h') .. '/' .. new_name
      if vim.fn.rename(old, new_path) == 0 then
        vim.cmd('edit ' .. vim.fn.fnameescape(new_path))
        vim.notify('Renamed to ' .. new_name, vim.log.levels.INFO)
      else
        vim.notify('Rename failed: ' .. new_path, vim.log.levels.ERROR)
      end
    end)
  end, { desc = '[F]ile [R]ename' })

  vim.keymap.set('n', '<leader>fd', function()
    local src = vim.fn.expand('%:p')
    local base = vim.fn.expand('%:t:r')
    local ext  = vim.fn.expand('%:e')
    local default = base .. '-copy' .. (ext ~= '' and '.' .. ext or '')
    vim.ui.input({ prompt = 'Duplicate as: ', default = default }, function(new_name)
      if not new_name or new_name == '' then return end
      local dest = vim.fn.expand('%:p:h') .. '/' .. new_name
      local ok, err = vim.uv.fs_copyfile(src, dest)
      if ok then
        vim.cmd('edit ' .. vim.fn.fnameescape(dest))
        vim.notify('Duplicated to ' .. new_name, vim.log.levels.INFO)
      else
        vim.notify('Duplicate failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end)
  end, { desc = '[F]ile [D]uplicate' })

  vim.keymap.set('n', '<leader>fn', function()
    local dir = vim.fn.expand('%:p:h')
    vim.ui.input({ prompt = 'New file: ', default = dir .. '/' }, function(path)
      if not path or path == '' then return end
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
    end)
  end, { desc = '[F]ile [N]ew' })

  vim.keymap.set('n', '<leader>fx', function()
    local old = vim.fn.expand('%:p')
    vim.ui.input({ prompt = 'Move/rename to: ', default = old }, function(new_path)
      if not new_path or new_path == '' or new_path == old then return end
      -- Create parent directories if needed
      local dir = vim.fn.fnamemodify(new_path, ':h')
      vim.fn.mkdir(dir, 'p')
      if vim.fn.rename(old, new_path) == 0 then
        vim.cmd('edit ' .. vim.fn.fnameescape(new_path))
        vim.notify('Moved to ' .. new_path, vim.log.levels.INFO)
      else
        vim.notify('Move failed: ' .. new_path, vim.log.levels.ERROR)
      end
    end)
  end, { desc = '[F]ile move and rename' })

  vim.keymap.set('n', '<leader>fc', function()
    local path = vim.fn.expand('%:p')
    vim.fn.setreg('+', path)
    vim.notify('Copied: ' .. path, vim.log.levels.INFO)
  end, { desc = '[F]ile path [C]opy' })

  -- Native session management (replaces persistence.nvim)
  local session_dir = vim.g._native_session_dir
    or (vim.fn.stdpath('data') .. '/sessions')

  vim.keymap.set('n', '<leader>us', function()
    local f = session_dir .. '/last.vim'
    if vim.fn.filereadable(f) == 1 then
      vim.cmd('source ' .. vim.fn.fnameescape(f))
      vim.notify('Session restored', vim.log.levels.INFO)
    else
      vim.notify('No saved session found', vim.log.levels.WARN)
    end
  end, { desc = '[U]tility [S]ession restore' })

  vim.keymap.set('n', '<leader>ud', function()
    if vim.g._session_disable then
      vim.g._session_disable()
    end
  end, { desc = "[U]tility session [D]on't save" })

  -- Undotree
  vim.keymap.set('n', '<leader>uu', '<cmd>UndotreeToggle<cr>', { desc = '[U]ndotree toggle' })
end

return M