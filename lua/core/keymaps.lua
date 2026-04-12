-- =============================================================================
-- Core Keymaps
-- Base keymaps from init.lua and lua/enhancement/config/keymaps.lua
-- =============================================================================

local map = vim.keymap.set

-- =============================================================================
-- BASIC
-- =============================================================================

-- Clear highlights on search when pressing <Esc> in normal mode
map('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
map('n', '<leader>xe', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
map('n', '<leader>xq', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- =============================================================================
-- NAVIGATION & WINDOW MANAGEMENT
-- =============================================================================

-- Window resizing
map('n', '>', [[<cmd>vertical resize +5<cr>]], { desc = 'Increase vertical size' })
map('n', '<', [[<cmd>vertical resize -5<cr>]], { desc = 'Decrease vertical size' })
map('n', '+', [[<cmd>horizontal resize +2<cr>]], { desc = 'Increase horizontal size' })
map('n', '-', [[<cmd>horizontal resize -2<cr>]], { desc = 'Decrease horizontal size' })
map('n', '=', [[<cmd>wincmd =<cr>]], { desc = 'Equalize window sizes' })

-- =============================================================================
-- BUFFER NAVIGATION
-- Replaces barbar.nvim commands with native Vim equivalents.
-- =============================================================================

--- Get the Nth listed buffer number (1-indexed position in buflisted order)
local function listed_buf_at(n)
	local bufs = vim.tbl_filter(function(b)
		return vim.api.nvim_get_option_value("buflisted", { buf = b })
	end, vim.api.nvim_list_bufs())
	return bufs[n]
end

--- Switch to the Nth listed buffer by position
local function goto_listed_buf(n)
	local buf = listed_buf_at(n)
	if buf then
		vim.api.nvim_win_set_buf(0, buf)
	end
end

--- Switch to the last listed buffer
local function goto_last_listed_buf()
	local bufs = vim.tbl_filter(function(b)
		return vim.api.nvim_get_option_value("buflisted", { buf = b })
	end, vim.api.nvim_list_bufs())
	if #bufs > 0 then
		vim.api.nvim_win_set_buf(0, bufs[#bufs])
	end
end

-- Jump to buffer by position (1-9, 0=last)
for i = 1, 9 do
	map('n', '<leader>' .. i, function() goto_listed_buf(i) end, { desc = 'Go to buffer ' .. i })
end
map('n', '<leader>0', goto_last_listed_buf, { desc = 'Go to last buffer' })

-- Previous/next buffer
map('n', '<C-h>', '<cmd>bprev<cr>', { desc = 'Previous buffer' })
map('n', '<C-l>', '<cmd>bnext<cr>', { desc = 'Next buffer' })

-- Close buffer (uses native bufdelete for safe window-layout-preserving close)
map('n', '<C-x>', function()
	require('core.native').bufdelete()
end, { desc = 'Close buffer' })

-- =============================================================================
-- TEXT EDITING ENHANCEMENTS
-- =============================================================================

-- Better indenting in visual mode
map('v', '<', '<gv', { desc = 'Indent left and reselect' })
map('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Move text up and down
map('v', 'J', ":m '>+1<cr>gv=gv", { desc = 'Move selection down' })
map('v', 'K', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

-- Better paste in visual mode
map('v', 'p', '"_dP', { desc = 'Paste without overwriting clipboard' })

-- Join lines without moving cursor
map('n', 'J', 'mzJ`z', { desc = 'Join lines without moving cursor' })

-- Center screen when navigating
map('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and center' })
map('n', 'n', 'nzzzv', { desc = 'Next search result and center' })
map('n', 'N', 'Nzzzv', { desc = 'Previous search result and center' })

-- =============================================================================
-- QUICK ACTIONS
-- =============================================================================

-- Clear search highlighting
map('n', '<leader>nh', '<cmd>nohl<cr>', { desc = 'Clear search highlight' })

-- Show file path
map('n', '<leader>fp', '<cmd>echo expand("%:p")<cr>', { desc = 'Show [F]ile [P]ath' })

-- Toggle line wrapping
map('n', '<leader>uw', '<cmd>set wrap!<cr>', { desc = 'Toggle line wrap' })

-- Toggle spell checking (use <leader>uS to avoid collision with session's <leader>us)
map('n', '<leader>uS', '<cmd>set spell!<cr>', { desc = 'Toggle [S]pell check' })

-- =============================================================================
-- THEME TOGGLE
-- =============================================================================

map('n', '<leader>ut', function()
  if _G.toggle_color_theme then
    _G.toggle_color_theme()
  else
    vim.notify('Theme toggle not available', vim.log.levels.ERROR)
  end
end, { desc = '[U]tility [T]heme toggle (Latte ↔ NGE)' })
