-- =============================================================================
-- Declarative plugin loading engine for vim.pack
-- Engine manages :packadd (adding to runtimepath + sourcing plugin/) so that
-- vim.pack.add can use load = function() end (no-op) to skip runtimepath entirely.
-- =============================================================================

local M = {}

-- Track loaded modules (one-time guard, same role as old core.lazy.setup)
local loaded = {}

-- Track packadd'd plugin directory names (deduplication)
local packadded = {}

--- Idempotent :packadd helper.
-- Adds plugin directory to runtimepath AND sources its plugin/ files.
-- Deduplicated via packadded table.
local function packadd(name)
  if not packadded[name] then
    packadded[name] = true
    vim.cmd.packadd(name)
  end
end

--- Load a single registry entry: packadd declared plugins, then require the module.
local function load_entry(entry)
  local load_key = entry.fn and (entry.mod .. '.' .. entry.fn) or entry.mod
  if loaded[load_key] then
    return
  end
  loaded[load_key] = true

  if entry.packadd then
    for _, name in ipairs(entry.packadd) do
      packadd(name)
    end
  end

  local ok, mod = pcall(require, 'plugins.' .. entry.mod)
  if not ok then
    vim.notify('[pack] ' .. entry.mod .. ': ' .. tostring(mod), vim.log.levels.ERROR)
    return
  end

  if entry.fn then
    if type(mod[entry.fn]) == 'function' then
      local fn_ok, err = pcall(mod[entry.fn])
      if not fn_ok then
        vim.notify('[pack] ' .. entry.mod .. '.' .. entry.fn .. '(): ' .. tostring(err), vim.log.levels.ERROR)
      end
    else
      vim.notify('[pack] ' .. entry.mod .. ' has no function ' .. entry.fn, vim.log.levels.ERROR)
    end
  end
end

--- Set up the loading engine.
-- @param registry  Array of entry tables:
--   { mod = 'name', event = 'Event', pattern = {...}, keys = {...}, defer = ms, packadd = {...}, once }
--   - event:   autocmd event string or array; creates one-shot autocmd (default once=true)
--   - pattern: autocmd pattern string or array (e.g. {'*.rs'}); defaults to all files
--   - keys:    array of { keystring, desc, mode }; sets temp keymap, loads on first press
--   - defer:   milliseconds; uses vim.defer_fn
--   - packadd: array of plugin directory names; :packadd each before require
--   - once:    for event entries; default true (load once then stop listening)
function M.setup(registry)
  for _, entry in ipairs(registry) do
    if entry.event then
      -- Event-triggered loading (UIEnter, BufReadPre, InsertEnter, BufWritePre, etc.)
      local events = type(entry.event) == 'table' and entry.event or { entry.event }
      local group_name = 'pack-' .. entry.mod .. (entry.fn and ('-' .. entry.fn) or '')
      local group = vim.api.nvim_create_augroup(group_name, { clear = true })
      vim.api.nvim_create_autocmd(events, {
        group = group,
        pattern = entry.pattern, -- nil means '*' (all files); specify e.g. {'*.rs'} to restrict
        once = entry.once ~= false, -- default true; set once=false for repeatable events like BufWritePre
        callback = function()
          load_entry(entry)
        end,
      })
    elseif entry.keys then
      -- Keymap-triggered loading: set a temp keymap, on first press load then replay.
      for _, k in ipairs(entry.keys) do
        local key = k[1]
        local desc = k.desc or ('Load ' .. entry.mod)
        local mode = k.mode or 'n'
        vim.keymap.set(mode, key, function()
          -- Remove the temp keymap so it doesn't fire again
          pcall(vim.keymap.del, mode, key)
          -- Load the module (which may register the "real" keymap)
          load_entry(entry)
          -- Replay the original keypress so the now-loaded plugin handles it
          local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
          vim.api.nvim_feedkeys(keys, 'mit', false)
        end, { desc = desc, nowait = true })
      end
    elseif entry.defer then
      -- Deferred loading (vim.defer_fn)
      vim.defer_fn(function()
        load_entry(entry)
      end, entry.defer)
    else
      -- Immediate loading (catppuccin on startup)
      load_entry(entry)
    end
  end
end

--- Returns list of loaded module names (for debugging)
function M.loaded()
  return vim.tbl_keys(loaded)
end

return M
