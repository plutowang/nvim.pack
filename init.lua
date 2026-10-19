-- =============================================================================
-- Neovim 0.12+ configuration using vim.pack + core.pack loading engine
-- =============================================================================

-- Enable the new Lua loader for faster startup
if vim.loader then
  vim.loader.enable()
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Disable built-in plugins we don't need
local disabled_built_ins = {
  'netrw', 'netrwPlugin', 'netrwSettings', 'netrwFileHandlers',
  'gzip', 'zip', 'zipPlugin', 'tar', 'tarPlugin',
  'getscript', 'getscriptPlugin', 'vimball', 'vimballPlugin',
  '2html_plugin', 'logipat', 'rrhelper', 'spellfile_plugin', 'matchit',
}
for _, plugin in ipairs(disabled_built_ins) do
  vim.g['loaded_' .. plugin] = 1
end

-- Core settings
require('core.options')
require('core.keymaps')
require('core.autocmds')

-- Plugin declarations (vim.pack.add with load = no-op) + loading engine setup.
-- require('plugins') does everything: installs plugins, registers the declarative
-- loading rules, and sets up autocmds / keymaps / deferred loaders.
require('plugins')
