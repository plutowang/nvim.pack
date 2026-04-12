-- Debugging: nvim-dap + dapui + dap-virtual-text + dap-go + mason-nvim-dap

-- Hover helpers (module-local, declared before setup_debugging so the
-- CursorHold callback inside it can close over these via lexical scoping)
local _hover_enabled = true

local function _show_dap_hover()
  local word = vim.fn.expand('<cword>')
  local session = require('dap').session()
  if not word or word == '' or not session then
    return
  end
  session:request('evaluate', { expression = word, context = 'hover' }, function(err, resp)
    if err or not resp or not resp.result then
      return
    end
    local content = ('󰍉 %s = %s'):format(word, resp.result)
    if resp.type then
      content = content .. ('\n󰋼 %s'):format(resp.type)
    end
    vim.lsp.util.open_floating_preview({ content }, 'markdown', {
      border = 'rounded',
      title = ' Debug Value ',
      title_pos = 'center',
      close_events = { 'CursorMoved', 'CursorMovedI', 'InsertEnter' },
    })
  end)
end

local function setup_debugging()
  -- nvim-dap-ui setup (must happen before dap listeners)
  require('dapui').setup({
    icons = {
      expanded = '󰅀',
      collapsed = '󰅂',
      current_frame = '󰁕',
    },
    controls = {
      enabled = true,
      element = 'repl',
      icons = {
        pause = '󰏤',
        play = '󰐊',
        step_into = '󰆹',
        step_over = '󰆷',
        step_out = '󰆸',
        step_back = '󰜢',
        run_last = '󰑮',
        terminate = '󰝤',
        disconnect = '󰖟',
      },
    },
    layouts = {
      {
        elements = {
          { id = 'scopes', size = 0.25 },
          { id = 'breakpoints', size = 0.25 },
          { id = 'stacks', size = 0.25 },
          { id = 'watches', size = 0.25 },
        },
        size = 40,
        position = 'left',
      },
      {
        elements = {
          { id = 'repl', size = 0.5 },
          { id = 'console', size = 0.5 },
        },
        size = 0.25,
        position = 'bottom',
      },
    },
    floating = {
      max_height = nil,
      max_width = nil,
      border = 'rounded',
      mappings = {
        close = { 'q', '<Esc>' },
      },
    },
    windows = { indent = 2 },
    render = {
      max_type_length = nil,
      max_value_lines = 100,
    },
  })

  -- nvim-dap-virtual-text setup
  require('nvim-dap-virtual-text').setup({
    enabled = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = true,
    show_stop_reason = true,
    only_first_definition = true,
    clear_on_continue = false,
    display_callback = function(variable)
      local value = variable.value or ''
      if #value > 50 then
        value = value:sub(1, 47) .. '...'
      end
      return ' = ' .. value
    end,
    virt_text_pos = vim.fn.has('nvim-0.10') == 1 and 'inline' or 'eol',
    all_frames = false,
    virt_lines = false,
    virt_text_win_col = nil,
  })

  -- nvim-dap-go setup
  require('dap-go').setup({
    delve = {
      detached = vim.fn.has('win32') == 0,
      build_flags = { '-tags', 'debug' },
    },
    dap_configurations = {
      { type = 'go', name = ' Debug Package', request = 'launch', program = '${workspaceFolder}' },
      { type = 'go', name = '󰙨 Debug Test', request = 'launch', mode = 'test', program = '${workspaceFolder}' },
      { type = 'go', name = '󰈔 Debug File', request = 'launch', program = '${file}' },
      { type = 'go', name = '󰌘 Attach Remote', mode = 'remote', request = 'attach' },
    },
  })

  -- mason-nvim-dap setup
  require('mason-nvim-dap').setup({
    automatic_installation = true,
    ensure_installed = {
      'delve',    -- Go debugger
      'codelldb', -- Rust & Zig debugger
    },
    handlers = {},
  })

  -- nvim-dap main configuration
  local dap = require('dap')
  local dapui = require('dapui')

  -- Breakpoint icons
  local breakpoint_icons = {
    Breakpoint = '●',
    BreakpointCondition = '◐',
    BreakpointRejected = '◌',
    LogPoint = '◆',
    Stopped = '▶',
  }
  for name, icon in pairs(breakpoint_icons) do
    local hl = name == 'Stopped' and 'DiagnosticWarn' or 'DiagnosticError'
    vim.fn.sign_define('Dap' .. name, { text = icon, texthl = hl, numhl = hl })
  end

  -- Auto-open/close DAP UI
  dap.listeners.after.event_initialized['dapui_config'] = function()
    local neo_tree_ok, neo_tree = pcall(require, 'neo-tree.command')
    if neo_tree_ok then
      neo_tree.execute({ action = 'close' })
    end
    dapui.open()
    vim.notify('󰃤 Debug session started', vim.log.levels.INFO, { title = 'DAP' })
  end

  dap.listeners.before.event_terminated['dapui_config'] = function()
    dapui.close()
    vim.notify('󰄬 Debug session terminated', vim.log.levels.INFO, { title = 'DAP' })
  end

  dap.listeners.before.event_exited['dapui_config'] = function()
    dapui.close()
    vim.notify('󰙨 Debug session exited', vim.log.levels.INFO, { title = 'DAP' })
  end

  -- codelldb adapter (Rust & Zig)
  dap.adapters.codelldb = {
    type = 'server',
    port = '${port}',
    executable = {
      command = 'codelldb',
      args = { '--port', '${port}' },
    },
  }

  -- Helper functions
  local function find_project_root(project_file)
    local file_path = vim.fn.findfile(project_file, '.;')
    if file_path == '' then return nil end
    return vim.fn.fnamemodify(file_path, ':h')
  end

  local function build_project(project_type, is_test)
    if project_type == 'rust' then
      local cmd = is_test and 'cargo test --no-run' or 'cargo build'
      vim.notify('󰜎 Building Rust project...', vim.log.levels.INFO, { title = 'DAP' })
      vim.fn.system(cmd)
    elseif project_type == 'zig' then
      local cmd = is_test and 'zig build test' or 'zig build'
      vim.notify('󰜎 Building Zig project...', vim.log.levels.INFO, { title = 'DAP' })
      vim.fn.system(cmd)
    end
  end

  local function get_executable_input(project_file, relative_path, fallback_path, prompt, project_type, is_test)
    if project_type then
      build_project(project_type, is_test)
    end
    local project_root = find_project_root(project_file)
    local target_path = project_root and (project_root .. '/' .. relative_path) or fallback_path
    return vim.fn.input(prompt, target_path, 'file')
  end

  -- Rust configurations
  dap.configurations.rust = {
    {
      name = '󱘗 Launch Rust',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return get_executable_input('Cargo.toml', 'target/debug/', vim.fn.getcwd() .. '/target/debug/', 'Path to executable: ', 'rust', false)
      end,
      cwd = '${workspaceFolder}',
      args = {},
      stopOnEntry = false,
    },
    {
      name = '󰙨 Debug Rust Tests',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return get_executable_input('Cargo.toml', 'target/debug/deps/', vim.fn.getcwd() .. '/target/debug/deps/', 'Path to test executable: ', 'rust', true)
      end,
      cwd = '${workspaceFolder}',
      args = { '--nocapture' },
      stopOnEntry = false,
    },
  }

  -- Zig configurations
  dap.configurations.zig = {
    {
      name = '󰠳 Launch Zig',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return get_executable_input('build.zig', 'zig-out/bin/', vim.fn.getcwd() .. '/zig-out/bin/', 'Path to executable: ', 'zig', false)
      end,
      cwd = '${workspaceFolder}',
      args = {},
      stopOnEntry = false,
    },
    {
      name = '󰙨 Debug Zig Tests',
      type = 'codelldb',
      request = 'launch',
      program = function()
        return get_executable_input('build.zig', 'zig-out/bin/', vim.fn.getcwd() .. '/zig-out/bin/', 'Path to test executable: ', 'zig', true)
      end,
      cwd = '${workspaceFolder}',
      stopOnEntry = false,
    },
  }

  -- Register CursorHold autocmd for DAP hover
  vim.api.nvim_create_autocmd('CursorHold', {
    group = vim.api.nvim_create_augroup('DapHover', { clear = true }),
    callback = function()
      if _hover_enabled and require('dap').session() then
        _show_dap_hover()
      end
    end,
  })
end

setup_debugging()

-- Keymaps
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<F7>', function() require('dapui').toggle() end, { desc = 'Debug: See last session result' })
vim.keymap.set('n', '<leader>dx', function() require('dap').clear_breakpoints() end, { desc = '[D]ebug Clear All Breakpoints' })
vim.keymap.set('n', '<leader>dC', function() require('dap').run_to_cursor() end, { desc = '[D]ebug Run to [C]ursor' })
vim.keymap.set('n', '<leader>dl', function() require('dap').run_last() end, { desc = '[D]ebug Run [L]ast' })
vim.keymap.set('n', '<leader>dt', function() require('dap').terminate() end, { desc = '[D]ebug [T]erminate' })
vim.keymap.set('n', '<leader>dp', function() require('dap').pause() end, { desc = '[D]ebug [P]ause' })
vim.keymap.set('n', '<leader>dfc', function() require('dap').continue() end, { desc = '<F5> [D]ebug [C]ontinue/Start' })
vim.keymap.set('n', '<leader>dfi', function() require('dap').step_into() end, { desc = '<F1> [D]ebug Step [I]nto' })
vim.keymap.set('n', '<leader>dfO', function() require('dap').step_over() end, { desc = '<F2> [D]ebug Step [O]ver' })
vim.keymap.set('n', '<leader>dfo', function() require('dap').step_out() end, { desc = '<F3> [D]ebug Step [O]ut' })
vim.keymap.set('n', '<leader>dir', function() require('dap').repl.toggle() end, { desc = '[D]ebug [I]nspection Toggle [R]EPL' })
vim.keymap.set('n', '<leader>dis', function() require('dap').session() end, { desc = '[D]ebug [I]nspection [S]ession Info' })
vim.keymap.set('n', '<leader>dgt', function() require('dap-go').debug_test() end, { desc = '[D]ebug [G]o [T]est' })
vim.keymap.set('n', '<leader>dgl', function() require('dap-go').debug_last_test() end, { desc = '[D]ebug [G]o [L]ast Test' })

vim.keymap.set('n', '<leader>dv', function()
  _hover_enabled = not _hover_enabled
  local status = _hover_enabled and '󰄬 Enabled' or '󰄭 Disabled'
  vim.notify('󰍉 Debug Hover: ' .. status, vim.log.levels.INFO, { title = 'DAP' })
end, { desc = 'Debug: Toggle variable hover', silent = true })

vim.keymap.set('n', '<leader>dr', function()
  local word = vim.fn.expand('<cword>')
  if word and word ~= '' then
    require('dap').repl.execute('p ' .. word)
  end
end, { desc = 'Debug: Evaluate in REPL', silent = true })

vim.keymap.set('n', '<leader>db', function()
  require('dap').toggle_breakpoint()
end, { desc = 'Toggle [D]ebug [B]reakpoint' })

vim.keymap.set('n', '<leader>dB', function()
  require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))
end, { desc = '[D]ebug [B]reakpoint Conditional' })

vim.keymap.set('n', '<leader>dfu', function()
  local current_wins = vim.api.nvim_list_wins()
  local dap_ui_open = false
  for _, win in ipairs(current_wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name:match('dap%-') then
      dap_ui_open = true
      break
    end
  end
  if not dap_ui_open then
    local neo_tree_ok, neo_tree = pcall(require, 'neo-tree.command')
    if neo_tree_ok then
      neo_tree.execute({ action = 'close' })
    end
  end
  require('dapui').toggle()
end, { desc = '<F7> [D]ebug [U]I Toggle' })

vim.keymap.set('n', '<leader>diw', function()
  require('dap.ui.widgets').hover()
end, { desc = '[D]ebug [I]nspection [W]idget Hover' })

vim.keymap.set('n', '<leader>diW', function()
  local widgets = require('dap.ui.widgets')
  widgets.centered_float(widgets.scopes)
end, { desc = '[D]ebug [I]nspection [W]idget Scopes' })

vim.keymap.set({ 'n', 'v' }, '<leader>diE', function()
  require('dapui').eval()
end, { desc = '[D]ebug [I]nspection [E]val Expression' })
