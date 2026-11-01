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

function M.images()
  -- Snacks is configured once; the markdown entry may run before VimEnter.
  require('plugins.snacks').setup()
  local snacks = require('snacks')
  if not snacks.config.image.enabled then return end
  -- snacks sets up the image module on BufReadPre; we load snacks during that
  -- same event, so the in-flight event is missed. Run it now (idempotent).
  snacks.image.setup()

  -- Workaround: markdown fence lines are concealed with `conceal_lines` (by the
  -- bundled markdown queries and render-markdown); such lines are not drawn at
  -- all. snacks anchors the diagram's trailing virtual lines to the closing
  -- fence row, so Neovim drops them and diagrams render cut off. Move the
  -- anchor up to the nearest row that is actually drawn.
  local Placement = require('snacks.image.placement')
  local function row_hidden(buf, row)
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, { row, 0 }, { row, -1 }, { details = true })) do
      local d = m[4]
      if d and d.conceal_lines ~= nil then
        return true
      end
    end
    return false
  end
  local render = Placement._render
  function Placement:_render(extmarks)
    for _, m in ipairs(extmarks or {}) do
      if m.virt_lines and m.row then
        local row = m.row
        while row > 0 and row_hidden(self.buf, row) do
          row = row - 1
        end
        if row ~= m.row then
          m.row = row
          m.virt_lines_above = false
        end
      end
    end
    return render(self, extmarks)
  end
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