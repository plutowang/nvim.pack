-- =============================================================================
-- Native replacements for snacks.nvim features
-- Implements: lazygit, terminal, bufdelete, gitbrowse, scratch
-- bigfile and quickfile are registered in plugins/ui.lua as pack entries
-- =============================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Floating window helper
-- ---------------------------------------------------------------------------
local function open_float_win(buf, opts)
  opts = opts or {}
  local width  = math.floor(vim.o.columns * (opts.width or 0.8))
  local height = math.floor(vim.o.lines   * (opts.height or 0.8))
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)

  return vim.api.nvim_open_win(buf, true, {
    relative  = 'editor',
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    border    = 'rounded',
    style     = 'minimal',
    title     = opts.title and (' ' .. opts.title .. ' ') or nil,
    title_pos = opts.title and 'center' or nil,
    zindex    = 50,
  })
end

-- ---------------------------------------------------------------------------
-- Terminal helper — opens a floating terminal running the given command.
-- Toggles: if the terminal is already visible, close it; otherwise open it.
-- Close: q (normal mode), <C-q> (terminal mode), or auto-close on clean exit.
-- Stays open on non-zero exit code so errors are visible; close with q/<C-q>.
-- opts.autoclose == false also keeps the window open (for long-running review).
-- ---------------------------------------------------------------------------
local _term_bufs = {} -- cmd_key → bufnr

local function close_float_by_buf(bufnr)
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      vim.api.nvim_win_close(winid, true)
      return
    end
  end
end

local function open_terminal(cmd, opts)
  opts = opts or {}
  local cmd_key = cmd or '__default__'
  local existing = _term_bufs[cmd_key]

  -- If the buffer is already visible in a window, close that window (toggle)
  if existing and vim.api.nvim_buf_is_valid(existing) then
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(winid) == existing then
        vim.api.nvim_win_close(winid, true)
        return
      end
    end
  end

  -- Create or reuse the terminal buffer
  local buf
  if existing and vim.api.nvim_buf_is_valid(existing) then
    buf = existing
  else
    buf = vim.api.nvim_create_buf(false, true)
    _term_bufs[cmd_key] = buf
  end

  open_float_win(buf, opts)

  if not existing or not vim.api.nvim_buf_is_valid(existing) then
    local shell_cmd = cmd and { vim.o.shell, '-c', cmd } or { vim.o.shell }
    vim.fn.termopen(shell_cmd, {
      on_exit = function(_, exit_code)
        vim.schedule(function()
          if opts.autoclose == false or exit_code ~= 0 then
            -- Keep the window open: either requested or process exited with error
            return
          end
          -- Auto-close the floating window and clean up the buffer on process exit
          _term_bufs[cmd_key] = nil
          close_float_by_buf(buf)
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      end,
    })
    _term_bufs[cmd_key] = buf
  end

  -- q in normal mode closes the floating window
  vim.keymap.set('n', 'q', function()
    close_float_by_buf(buf)
  end, { buffer = buf, desc = 'Close terminal window' })

  -- <C-q> in terminal mode exits terminal mode and closes the window
  vim.keymap.set('t', '<C-q>', function()
    vim.cmd('stopinsert')
    close_float_by_buf(buf)
  end, { buffer = buf, desc = 'Exit and close terminal window' })

  vim.cmd('startinsert')
end

-- ---------------------------------------------------------------------------
-- Terminal
-- ---------------------------------------------------------------------------

function M.terminal_float()
  open_terminal(nil, { title = 'Terminal' })
end

function M.terminal_repl(prog)
  open_terminal(prog, { title = prog })
end

-- ---------------------------------------------------------------------------
-- Lazygit
-- ---------------------------------------------------------------------------

function M.lazygit()
  if vim.fn.executable('lazygit') == 0 then
    vim.notify('lazygit not found in PATH', vim.log.levels.ERROR)
    return
  end
  open_terminal('lazygit', { title = 'lazygit' })
end

function M.lazygit_log()
  if vim.fn.executable('lazygit') == 0 then
    vim.notify('lazygit not found in PATH', vim.log.levels.ERROR)
    return
  end
  -- Open lazygit on current file's directory with log view
  local dir = vim.fn.expand('%:p:h')
  open_terminal('lazygit -p "' .. dir .. '" log', { title = 'Git Log' })
end

-- ---------------------------------------------------------------------------
-- Buffer delete — safe close preserving window layout
-- Switches to the previous listed buffer before deleting, so windows
-- don't close. Falls back to a new scratch buffer if none available.
-- ---------------------------------------------------------------------------

--- Returns a list of all listed buffer numbers.
local function listed_bufs()
  return vim.tbl_filter(function(b)
    return vim.api.nvim_get_option_value('buflisted', { buf = b })
  end, vim.api.nvim_list_bufs())
end

--- Switch the current window to an alternate buffer, then delete `bufnr`.
local function safe_delete(bufnr, force)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  -- Check for unsaved changes
  if not force and vim.api.nvim_get_option_value('modified', { buf = bufnr }) then
    local choice = vim.fn.confirm(
      'Buffer has unsaved changes. Delete anyway?',
      '&Yes\n&No', 2
    )
    if choice ~= 1 then return end
  end

  -- Find all windows displaying this buffer
  local wins = vim.tbl_filter(function(w)
    return vim.api.nvim_win_get_buf(w) == bufnr
  end, vim.api.nvim_list_wins())

  -- For each window, switch to an alternate buffer
  if #wins > 0 then
    local alt = nil
    for _, b in ipairs(listed_bufs()) do
      if b ~= bufnr then alt = b; break end
    end
    if not alt then
      alt = vim.api.nvim_create_buf(false, true) -- scratch fallback
    end
    for _, win in ipairs(wins) do
      vim.api.nvim_win_set_buf(win, alt)
    end
  end

  pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
end

function M.bufdelete()
  safe_delete(vim.api.nvim_get_current_buf(), false)
end

function M.bufdelete_force()
  safe_delete(vim.api.nvim_get_current_buf(), true)
end

function M.bufdelete_other()
  local current = vim.api.nvim_get_current_buf()
  for _, b in ipairs(listed_bufs()) do
    if b ~= current then
      safe_delete(b, false)
    end
  end
end

function M.bufdelete_all()
  for _, b in ipairs(listed_bufs()) do
    safe_delete(b, false)
  end
end

-- ---------------------------------------------------------------------------
-- Git browse — open current file/selection in the remote repository web UI
-- ---------------------------------------------------------------------------

local function git_remote_url()
  local result = vim.system({ 'git', 'remote', 'get-url', 'origin' }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout then return nil end
  return result.stdout:gsub('%s+$', '')
end

local function normalize_git_url(url)
  -- Strip embedded credentials: https://oauth2:token@host/... → https://host/...
  url = url:gsub('^(https?://)[^@]+@', '%1')
  -- SSH: git@github.com:user/repo.git  →  https://github.com/user/repo
  url = url:gsub('^git@([^:]+):(.+)$', 'https://%1/%2')
  -- Remove .git suffix
  url = url:gsub('%.git$', '')
  return url
end

function M.gitbrowse()
  local remote = git_remote_url()
  if not remote then
    vim.notify('No git remote found', vim.log.levels.WARN)
    return
  end

  local base_url = normalize_git_url(remote)

  -- Get current branch
  local branch_res = vim.system({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }, { text = true }):wait()
  local branch = branch_res.code == 0 and branch_res.stdout:gsub('%s+$', '') or 'main'

  -- Build URL: base/blob/branch/filepath#Lline
  local filepath = vim.fn.expand('%:.')  -- relative to cwd
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local url = base_url .. '/blob/' .. branch .. '/' .. filepath .. '#L' .. line

  vim.notify('Opening: ' .. url, vim.log.levels.INFO)
  vim.ui.open(url)
end

-- ---------------------------------------------------------------------------
-- Scratch buffer
-- ---------------------------------------------------------------------------

local _scratch_bufs = {}  -- ft → bufnr

--- Open a scratch float and attach close keymap (idempotent — keymap is buffer-local).
local function open_scratch_win(buf, title)
  open_float_win(buf, { title = title })
  vim.keymap.set('n', 'q', function()
    close_float_by_buf(buf)
  end, { buffer = buf, desc = 'Close scratch window' })
end

function M.scratch()
  local ft = vim.bo.filetype ~= '' and vim.bo.filetype or 'text'
  local existing = _scratch_bufs[ft]

  -- Toggle: if scratch is visible, close it
  if existing and vim.api.nvim_buf_is_valid(existing) then
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(winid) == existing then
        vim.api.nvim_win_close(winid, true)
        return
      end
    end
    -- Not visible — reopen it
    open_scratch_win(existing, 'Scratch (' .. ft .. ')')
    return
  end

  -- Create fresh scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype  = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = ft
  vim.api.nvim_buf_set_name(buf, 'Scratch[' .. ft .. ']')
  _scratch_bufs[ft] = buf

  open_scratch_win(buf, 'Scratch (' .. ft .. ')')
end

function M.scratch_select()
  local items = {}
  for ft, buf in pairs(_scratch_bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      table.insert(items, ft)
    end
  end
  if #items == 0 then
    M.scratch()
    return
  end
  vim.ui.select(items, { prompt = 'Select scratch buffer: ' }, function(choice)
    if not choice then return end
    local buf = _scratch_bufs[choice]
    if buf and vim.api.nvim_buf_is_valid(buf) then
      open_scratch_win(buf, 'Scratch (' .. choice .. ')')
    end
  end)
end

return M
