local M = {}

function M.markdown()
  -- render-markdown
  require('render-markdown').setup {
    file_types = { 'markdown' },
    latex = { enabled = false },
    completions = {
      lsp = { enabled = true },
    },
  }
end

function M.colorizer()
  -- nvim-colorizer
  local _setup_done = false

  vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('nvimpack-colorizer', { clear = true }),
    pattern = { 'css', 'scss', 'html', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
    callback = function()
      if _setup_done then return end
      _setup_done = true
      require('colorizer').setup {
        filetypes = { 'css', 'scss', 'html', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          names = true,
          RRGGBBAA = true,
          AARRGGBB = false,
          rgb_fn = true,
          hsl_fn = true,
          css = true,
          css_fn = true,
          mode = 'background',
          tailwind = 'both',
          sass = { enable = false },
          virtualtext = '■',
          always_update = false,
        },
        buftypes = {},
      }
    end,
  })
end

function M.guess_indent()
  -- guess-indent
  require('guess-indent').setup {
    auto_cmd = true,
    override_editorconfig = false,
    filetype_exclude = {
      'netrw',
      'tutor',
      'help',
      'qf',
      'diff',
      'fzf',
      'lazy',
      'mason',
    },
    buftype_exclude = {
      'help',
      'nofile',
      'terminal',
      'prompt',
    },
    on_tab_options = {
      ['expandtab'] = false,
    },
    on_space_options = {
      ['expandtab'] = true,
      ['tabstop'] = 'detected',
      ['softtabstop'] = 'detected',
      ['shiftwidth'] = 'detected',
    },
  }
end

function M.todo_comments()
  -- todo-comments
  require('todo-comments').setup { signs = false }
end

return M