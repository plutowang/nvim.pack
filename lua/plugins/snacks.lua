-- Snacks: fuzzy picker + markdown image rendering.
-- All Snacks configuration lives here because Snacks.setup is single-shot.

local M = {}
local gitignore = require('core.gitignore')
-- Image conversion needs ImageMagick (identify is part of it). Without it,
-- enabling the doc image module only produces conversion failures.
local has_image_converter = vim.fn.executable('magick') == 1 or vim.fn.executable('identify') == 1
local configured = false

--- fd args that keep `docs/` searchable while still respecting .gitignore.
--- Returns nil when docs/ is not gitignored, so fd keeps its default behavior.
local function files_args()
  local ignore = gitignore.ignore_file()
  if not ignore then return nil end
  return { '--type', 'f', '--strip-cwd-prefix', '--no-ignore-vcs', '--ignore-file', ignore }
end

--- rg args with the same docs/ whitelist contract.
local function grep_args()
  local ignore = gitignore.ignore_file()
  if not ignore then return nil end
  return { '--no-ignore-vcs', '--ignore-file', ignore }
end

--- grep_word replaces its default args, so --word-regexp must be re-added.
local function word_args()
  local ignore = gitignore.ignore_file()
  if not ignore then return { '--word-regexp' } end
  return { '--word-regexp', '--no-ignore-vcs', '--ignore-file', ignore }
end

function M.setup()
  if configured then return end
  configured = true

  local snacks = require('snacks')
  snacks.setup({
    image = {
      enabled = has_image_converter,
      doc = {
        enabled = true,
        inline = true,
        conceal = function(_, type)
          return type == 'math' or type == 'chart'
        end,
      },
      convert = { notify = false },
    },
    explorer = { replace_netrw = true, trash = true },
    picker = {
      ui_select = true,
      sources = {
        explorer = {
          layout = { preset = 'sidebar', layout = { width = 0.15, min_width = 30 } },
          hidden = false,
          ignored = true,
          follow_file = true,
          git_status = true,
          git_untracked = true,
          diagnostics = true,
          include = { '.gitattributes', '.gitignored', '.github', '.ci', '.opencode', '.agents' },
          exclude = {
            '*/.git', '*/node_modules', '*/__pycache__', '*/.pytest_cache', '*/.mypy_cache',
            '*/.ruff_cache', '*/.venv', '*/venv', '*/env', '*/.svn', '*/spell', '*/ENV',
            '*/env.bak', '*/venv.bak', '*/.Python', '*/src/*/tsconfig.json',
            '*/.DS_Store', '*/thumbs.db', '*.tmp', '*.temp', '*.pyc', '*.pyo', '*.pyd',
          },
        },
      },
    },
  })

  vim.keymap.set('n', '<leader>sh', function() snacks.picker.help() end,
    { desc = '[S]earch [H]elp' })
  vim.keymap.set('n', '<leader>sk', function() snacks.picker.keymaps({ global = true, ['local'] = true }) end,
    { desc = '[S]earch [K]eymaps' })
  vim.keymap.set('n', '<leader>sf', function() snacks.picker.files({ cmd = 'fd', args = files_args() }) end,
    { desc = '[S]earch [F]iles' })
  vim.keymap.set('n', '<leader>ss', function() snacks.picker.pickers() end,
    { desc = '[S]earch [S]elect Picker' })
  vim.keymap.set('n', '<leader>sw', function() snacks.picker.grep_word({ args = word_args() }) end,
    { desc = '[S]earch current [W]ord' })
  vim.keymap.set('n', '<leader>sd', function() snacks.picker.diagnostics() end,
    { desc = '[S]earch [D]iagnostics' })
  vim.keymap.set('n', '<leader>sr', function() snacks.picker.resume() end,
    { desc = '[S]earch [R]esume' })
  vim.keymap.set('n', '<leader>s.', function() snacks.picker.recent() end,
    { desc = '[S]earch Recent Files ("." for repeat)' })
  vim.keymap.set('n', '<leader>sg', function() snacks.picker.grep({ live = true, regex = false, args = grep_args() }) end,
    { desc = '[S]earch by [G]rep (literal, <a-r> regex)' })
  vim.keymap.set('n', '<leader>sl', function() snacks.picker.git_log() end,
    { desc = '[S]earch Git [L]og' })
  vim.keymap.set('n', '<leader>sL', function() snacks.picker.git_log_file() end,
    { desc = '[S]earch Git Log Current Fi[L]e' })
  vim.keymap.set('n', '<leader>s/', function() snacks.picker.grep_buffers({ need_search = true }) end,
    { desc = '[S]earch [/] in Open Files' })
  vim.keymap.set('n', '<leader>sn', function() snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end,
    { desc = '[S]earch [N]eovim files' })
  vim.keymap.set('n', '<leader><leader>', function() snacks.picker.buffers() end,
    { desc = '[ ] Find existing buffers' })
  vim.keymap.set('n', '<leader>/', function()
    snacks.picker.lines({ layout = { preset = 'dropdown', preview = false } })
  end, { desc = '[/] Fuzzily search in current buffer' })
  vim.keymap.set('n', '<leader>er', function()
    snacks.explorer({ cwd = vim.fs.root(0, '.git') or vim.uv.cwd() })
  end, { desc = '[E]xplorer [R]oot' })
  vim.keymap.set('n', '<leader>ef', function()
    snacks.explorer({ cwd = vim.uv.cwd() })
  end, { desc = '[E]xplorer [F]ile' })
end

--- Close the explorer if it is open (used by the DAP auto-open hook).
function M.close_explorer()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return end
  local picker = snacks.picker.get({ source = 'explorer' })[1]
  if picker then picker:close() end
end

return M
