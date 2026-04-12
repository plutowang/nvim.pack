-- neo-tree
require('neo-tree').setup({
  auto_clean_after_session_restore = true,
  close_if_last_window = false,
  enable_diagnostics = true,
  enable_git_status = true,
  enable_modified_markers = true,
  enable_refresh_on_write = true,
  popup_border_style = 'rounded',
  sort_case_insensitive = true,
  sort_function = nil,
  use_popups_for_input = true,

  default_component_configs = {
    container = {
      enable_character_fade = true,
    },
    indent = {
      indent_size = 2,
      padding = 1,
      with_markers = true,
      indent_marker = '│',
      last_indent_marker = '└',
      highlight = 'NeoTreeIndentMarker',
      with_expanders = nil,
      expander_collapsed = '',
      expander_expanded = '',
      expander_highlight = 'NeoTreeExpander',
    },
  },

  filesystem = {
    follow_current_file = {
      enabled = true,
      leave_dirs_open = false,
    },
    hijack_netrw_behavior = 'open_default',
    use_libuv_file_watcher = true,
    scan_mode = 'shallow',
    filtered_items = {
      visible = false,
      hide_dotfiles = true,
      hide_gitignored = true,
      hide_hidden = true,
      hide_by_name = {
        '.DS_Store', 'thumbs.db', 'node_modules', '.git', '.svn',
        '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache',
        '*.pyc', '*.pyo', '*.pyd', '.Python', 'env', 'venv',
        '.env', '.venv', 'ENV', 'env.bak', 'venv.bak',
      },
      hide_by_pattern = {
        '*/src/*/tsconfig.json',
        '*.tmp',
        '*.temp',
      },
      always_show = {
        '.gitignored',
        '.gitattributes',
        '.github',
        '.ci',
		    '.opencode',
		    '.agents',
      },
      never_show = {
        '.DS_Store',
        'thumbs.db',
      },
      never_show_by_pattern = {
        '.null-ls_*',
        '*.tmp',
        '.#*',
      },
    },
    bind_to_cwd = true,
    cwd_target = {
      sidebar = 'tab',
      current = 'window',
    },
  },

  buffers = {
    follow_current_file = {
      enabled = true,
      leave_dirs_open = false,
    },
    group_empty_dirs = true,
    show_unloaded = true,
  },

  window = {
    position = 'left',
    width = '15%',
    auto_expand_width = false,
  },
})

vim.keymap.set('n', '<leader>er', function()
  require('neo-tree.command').execute({ toggle = true, dir = '/' })
end, { desc = '[E]xplorer [R]oot' })
vim.keymap.set('n', '<leader>ef', function()
  require('neo-tree.command').execute({ toggle = true, dir = vim.uv.cwd() })
end, { desc = '[E]xplorer [F]ile' })
vim.keymap.set('n', '<leader>eg', function()
  require('neo-tree.command').execute({ source = 'git_status', toggle = true })
end, { desc = '[E]xplorer [G]it' })
vim.keymap.set('n', '<leader>eb', function()
  require('neo-tree.command').execute({ source = 'buffers', toggle = true })
end, { desc = '[E]xplorer [B]uffer' })

-- flash.nvim
require('flash').setup({
  modes = {
    enabled = true,
  },
  char = {
    jump_labels = true,
  },
})

vim.keymap.set({ 'n', 'x', 'o' }, 'gl', function() require('flash').jump() end, { desc = 'Flash: Go Leap' })
vim.keymap.set({ 'n', 'x', 'o' }, 'gL', function() require('flash').treesitter() end, { desc = 'Flash: Go Leap Treesitter' })
vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = 'Remote Flash' })
vim.keymap.set({ 'o', 'x' }, 'R', function() require('flash').treesitter_search() end, { desc = 'Treesitter Search' })
vim.keymap.set('c', '<c-s>', function() require('flash').toggle() end, { desc = 'Toggle Flash Search' })

-- nvim-spider
require('spider').setup({
  skipInsignificantPunctuation = true,
})

vim.keymap.set({ 'n', 'o', 'x' }, 'w', '<cmd>lua require("spider").motion("w")<CR>', { desc = 'Spider-w' })
vim.keymap.set({ 'n', 'o', 'x' }, 'e', '<cmd>lua require("spider").motion("e")<CR>', { desc = 'Spider-e' })
vim.keymap.set({ 'n', 'o', 'x' }, 'b', '<cmd>lua require("spider").motion("b")<CR>', { desc = 'Spider-b' })
vim.keymap.set({ 'n', 'o', 'x' }, 'ge', '<cmd>lua require("spider").motion("ge")<CR>', { desc = 'Spider-ge' })
