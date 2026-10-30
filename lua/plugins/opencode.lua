-- OpenCode integration (talks to the OpenCode server over HTTP/SSE).
-- Loaded on first keypress only: the plugin starts an OpenCode process when it
-- cannot find a running daemon, which must never happen at startup.
-- OpenCode v2: defaults target the `main` branch; override via vim.g.opencode_opts.

local M = {}

function M.setup()
  vim.keymap.set({ 'n', 'x' }, '<leader>oa', function()
    require('opencode').ask('@this: ')
  end, { desc = '[O]penCode [A]sk' })

  vim.keymap.set({ 'n', 'x' }, '<leader>os', function()
    require('opencode').select()
  end, { desc = '[O]penCode [S]elect' })

  vim.keymap.set({ 'n', 'x' }, 'go', function()
    return require('opencode').operator('@this')
  end, { desc = 'Send range to OpenCode', expr = true })

  vim.keymap.set('n', 'goo', function()
    return require('opencode').operator('@this') .. '_'
  end, { desc = 'Send line to OpenCode', expr = true })
end

return M
