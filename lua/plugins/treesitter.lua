local M = {}

function M.base()
  -- nvim-treesitter (main branch — Neovim 0.12+)
  require('nvim-treesitter').setup {}

  -- Register htmlangular filetype → angular parser
  vim.treesitter.language.register('angular', 'htmlangular')

  -- Highlight every filetype with an installed parser
  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('nvimpack-treesitter', { clear = true }),
    callback = function(args)
      pcall(vim.treesitter.start, args.buf)
    end,
  })

  -- Catch up: initial buffer's FileType fires before UIEnter
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= '' then
      pcall(vim.treesitter.start, buf)
    end
  end

  -- Auto-install missing parsers (deferred 500ms to not block startup)
  vim.defer_fn(function()
    local ensure_installed = {
      'angular', 'astro', 'bash', 'c', 'diff', 'cpp', 'sql',
      'css', 'go', 'graphql', 'html', 'http', 'javascript',
      'json', 'lua', 'luadoc', 'markdown', 'markdown_inline',
      'query', 'python', 'regex', 'rust', 'toml', 'tsx', 'typescript',
      'vim', 'vimdoc', 'xml', 'yaml', 'zig', 'git_config',
      'gitcommit', 'git_rebase', 'gitignore', 'gitattributes',
      'gowork', 'gomod', 'gosum', 'gotmpl', 'comment',
    }

    local installed = require('nvim-treesitter.config').get_installed()
    local missing = {}

    for _, lang in ipairs(ensure_installed) do
      if not vim.list_contains(installed, lang) then
        table.insert(missing, lang)
      end
    end

    if #missing > 0 then
      require('nvim-treesitter.install').install(missing, { summary = true })
    end
  end, 500)
end

function M.context()
  -- nvim-treesitter-context
  require('treesitter-context').setup({
    enable = true,
    multiwindow = false,
    max_lines = 2,
    min_window_height = 25,
    line_numbers = false,
    multiline_threshold = 15,
    trim_scope = 'outer',
    mode = 'cursor',
    throttle = true,
    separator = nil,
    zindex = 20,
    on_attach = function(buf)
      local filetype = vim.bo[buf].filetype
      local disabled_filetypes = {
        'help', 'alpha', 'dashboard', 'neo-tree',
        'Trouble', 'trouble', 'lazy', 'mason',
        'notify', 'toggleterm', 'lazyterm',
      }
      return not vim.tbl_contains(disabled_filetypes, filetype)
    end,
  })

  -- Treesitter context highlight overrides (dynamic Catppuccin colors)
  local function set_treesitter_context_colors()
    local ok, palettes = pcall(require, 'catppuccin.palettes')
    if not ok then return end
    local palette = palettes.get_palette()
    vim.api.nvim_set_hl(0, 'TreesitterContext', { bg = palette.surface0, fg = palette.text })
    vim.api.nvim_set_hl(0, 'TreesitterContextLineNumber', { bg = palette.surface0, fg = palette.overlay1, italic = true })
    vim.api.nvim_set_hl(0, 'TreesitterContextSeparator', { fg = palette.lavender, bg = palette.surface0 })
    vim.api.nvim_set_hl(0, 'TreesitterContextBottom', { bg = palette.surface0, sp = palette.blue, underline = true })
    vim.api.nvim_set_hl(0, 'TreesitterContextLineNumberBottom', {
      bg = palette.surface0, fg = palette.overlay1, sp = palette.blue, underline = true, italic = true,
    })
  end

  set_treesitter_context_colors()

  -- Re-apply colors when theme changes
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = set_treesitter_context_colors,
  })

  vim.keymap.set('n', '[C', function()
    require('treesitter-context').go_to_context(vim.v.count1)
  end, { desc = 'Jump to context (upwards)' })
  vim.keymap.set('n', '<leader>tc', '<cmd>TSContext toggle<cr>', { desc = 'Toggle Treesitter Context' })

  -- nvim-treesitter-textobjects
  require('nvim-treesitter-textobjects').setup {
    select = { lookahead = true },
    move   = { set_jumps = true },
  }

  local sel = require('nvim-treesitter-textobjects.select')
  local mov = require('nvim-treesitter-textobjects.move')
  local swp = require('nvim-treesitter-textobjects.swap')

  -- Select textobjects
  for _, map in ipairs({
    { 'am', '@function.outer',  'Select [A]round [M]ethod' },
    { 'im', '@function.inner',  'Select [I]nside [M]ethod' },
    { 'ac', '@class.outer',     'Select [A]round [C]lass' },
    { 'ic', '@class.inner',     'Select [I]nside [C]lass' },
    { 'aa', '@parameter.outer', 'Select [A]round p[a]rameter' },
    { 'ia', '@parameter.inner', 'Select [I]nside p[a]rameter' },
    { 'ab', '@block.outer',     'Select [A]round [b]lock' },
    { 'ib', '@block.inner',     'Select [I]nside [b]lock' },
  }) do
    vim.keymap.set({ 'x', 'o' }, map[1], function()
      sel.select_textobject(map[2], 'textobjects')
    end, { desc = map[3] })
  end

  -- Move to textobjects
  for _, map in ipairs({
    { ']m',  'goto_next_start',     '@function.outer',  'Next [m]ethod start' },
    { ']]',  'goto_next_start',     '@class.outer',     'Next class start' },
    { ']a',  'goto_next_start',     '@parameter.outer', 'Next p[a]rameter start' },
    { ']b',  'goto_next_start',     '@block.outer',     'Next [b]lock start' },
    { ']M',  'goto_next_end',       '@function.outer',  'Next [M]ethod end' },
    { '][',  'goto_next_end',       '@class.outer',     'Next class end' },
    { ']A',  'goto_next_end',       '@parameter.outer', 'Next p[A]rameter end' },
    { ']B',  'goto_next_end',       '@block.outer',     'Next [B]lock end' },
    { '[m',  'goto_previous_start', '@function.outer',  'Previous [m]ethod start' },
    { '[[',  'goto_previous_start', '@class.outer',     'Previous class start' },
    { '[a',  'goto_previous_start', '@parameter.outer', 'Previous p[a]rameter start' },
    { '[b',  'goto_previous_start', '@block.outer',     'Previous [b]lock start' },
    { '[M',  'goto_previous_end',   '@function.outer',  'Previous [M]ethod end' },
    { '[]',  'goto_previous_end',   '@class.outer',     'Previous class end' },
    { '[A',  'goto_previous_end',   '@parameter.outer', 'Previous p[A]rameter end' },
    { '[B',  'goto_previous_end',   '@block.outer',     'Previous [B]lock end' },
  }) do
    vim.keymap.set({ 'n', 'x', 'o' }, map[1], function()
      mov[map[2]](map[3], 'textobjects')
    end, { desc = map[4] })
  end

  -- Swap textobjects
  vim.keymap.set('n', '<leader>wa', function()
    swp.swap_next('@parameter.inner')
  end, { desc = 'S[w]ap p[a]rameter with next' })
  vim.keymap.set('n', '<leader>wA', function()
    swp.swap_previous('@parameter.inner')
  end, { desc = 'S[w]ap p[A]rameter with previous' })
  vim.keymap.set('n', '<leader>wm', function()
    swp.swap_next('@function.outer')
  end, { desc = 'S[w]ap [m]ethod with next' })
  vim.keymap.set('n', '<leader>wM', function()
    swp.swap_previous('@function.outer')
  end, { desc = 'S[w]ap [M]ethod with previous' })
end

return M