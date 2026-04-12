local M = {}

function M.base_ui()
  -- indent-blankline
  require('ibl').setup({
    indent = {
      char = '│',
      tab_char = '│',
    },
    scope = {
      char = '│',
      show_start = false,
      show_end = false,
      highlight = { 'Function', 'Label' },
    },
    exclude = {
      filetypes = {
        'help',
        'alpha',
        'dashboard',
        'neo-tree',
        'Trouble',
        'trouble',
        'lazy',
        'mason',
        'notify',
        'toggleterm',
        'lazyterm',
      },
    },
  })

  -- rainbow-delimiters
  local rainbow_delimiters = require('rainbow-delimiters')
  vim.g.rainbow_delimiters = {
    strategy = {
      [''] = rainbow_delimiters.strategy['global'],
      vim = rainbow_delimiters.strategy['local'],
    },
    query = {
      [''] = 'rainbow-delimiters',
      lua = 'rainbow-blocks',
    },
    priority = {
      [''] = 110,
      lua = 210,
    },
    highlight = {
      'RainbowDelimiterRed',
      'RainbowDelimiterYellow',
      'RainbowDelimiterBlue',
      'RainbowDelimiterOrange',
      'RainbowDelimiterGreen',
      'RainbowDelimiterViolet',
      'RainbowDelimiterCyan',
    },
  }
end

function M.autopairs()
  require('nvim-autopairs').setup({})
end

function M.surround()
  require('nvim-surround').setup({})
end

function M.grug_far()
  require('grug-far').setup({ headerMaxWidth = 80 })
  vim.keymap.set('n', '<leader>sR', '<cmd>GrugFar<CR>', { desc = '[S]earch and [R]eplace' })
  vim.keymap.set('n', '<leader>sW', function()
    require('grug-far').open({ prefills = { search = vim.fn.expand('<cword>') } })
  end, { desc = '[S]earch and replace current [W]ord' })
end

function M.treesj()
  require('treesj').setup({
    use_default_keymaps = false,
    max_join_length = 120,
  })
  vim.keymap.set('n', 'gS', function() require('treesj').split() end, { desc = 'Split node under cursor' })
  vim.keymap.set('n', 'gJ', function() require('treesj').join() end, { desc = 'Join node under cursor' })
end

function M.format()
  -- conform.nvim code formatter
  require('conform').setup {
    notify_on_error = true,
    format_on_save = function(bufnr)
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      else
        return {
          timeout_ms = 500,
          lsp_format = 'fallback',
        }
      end
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      go = { 'goimports', 'gofmt' },
      rust = { 'rustfmt', lsp_format = 'fallback' },
      zig = { 'zig_fmt' },
      javascript = { 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      html = { 'prettierd', 'prettier', stop_after_first = true },
      graphql = { 'prettierd', 'prettier', stop_after_first = true },
      css = { 'prettierd', 'prettier', stop_after_first = true },
      scss = { 'prettierd', 'prettier', stop_after_first = true },
      htmlangular = { 'prettierd', 'prettier', stop_after_first = true },
      sql = { 'prettierd', 'prettier', stop_after_first = true },
      yaml = { 'yamlfix' },
      toml = { 'taplo' },
      ['*'] = { 'codespell' },
      ['_'] = { 'trim_whitespace' },
    },
    formatters = {
      zig_fmt = {
        command = 'zig',
        args = { 'fmt', '--stdin' },
        stdin = true,
      },
    },
  }

  -- Format keymap
  vim.keymap.set('', '<leader>f', function()
    require('conform').format { async = true, lsp_format = 'fallback' }
  end, { desc = '[F]ormat buffer' })
end

return M