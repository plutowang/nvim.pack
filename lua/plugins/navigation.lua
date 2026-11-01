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
