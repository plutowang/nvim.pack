-- Cached .gitignore filter that removes docs/ entries so they become
-- visible in the picker and other tools. When a project has docs/ in
-- .gitignore, this module provides a filtered ignore file containing
-- everything EXCEPT docs/. Consumers use --ignore-file to feed it to fd/rg.
--
-- Cache is keyed on (cwd, .gitignore mtime) so the file is re-parsed
-- only when .gitignore changes. Returns nil if docs/ is not in .gitignore
-- (zero overhead for unaffected projects).

local M = {}

-- cache[cwd .. '\0' .. mtime_sec] = sentinel (no docs) or filepath (docs found)
local cache = {}
local SENTINEL = {}

--- Check whether a gitignore line refers to docs/ as a path component.
--- Matches: docs, docs/, /docs, /docs/..., docs/foo
--- Does NOT match: local-docs, docserver (prefixed/suffixed without / boundary)
local is_docs_line do
  local function _(line)
    -- Match docs or docs/ at start of line (root-level)
    if line:match('^docs$') or line:match('^docs/') then return true end
    -- Match /docs anywhere (path component)
    if line:find('/docs', 1, true) then return true end
    return false
  end
  is_docs_line = _
end

local function filter_gitignore(cwd)
  local path = cwd .. '/.gitignore'
  local stat = vim.uv.fs_stat(path)
  if not stat then return nil end

  local key = cwd .. '\0' .. tostring(stat.mtime.sec)
  local cached = cache[key]
  if cached then
    if cached == SENTINEL then return nil end
    return cached
  end

  local has_docs = false
  local kept = {}
  for line in io.lines(path) do
    if is_docs_line(line) then
      has_docs = true
    else
      kept[#kept + 1] = line
    end
  end

  if not has_docs then
    cache[key] = SENTINEL
    return nil
  end

  -- Write the filtered file (docs lines removed) to a stable temp path.
  local dir = vim.fn.stdpath('cache') .. '/gitignore'
  vim.fn.mkdir(dir, 'p')
  local out = dir .. '/docs-whitelist'
  local f, err = io.open(out, 'w')
  if not f then
    vim.notify('core.gitignore: write error: ' .. (err or 'nil'), vim.log.levels.WARN)
    cached = false
    cache[key] = cached
    return cached
  end

  for _, line in ipairs(kept) do
    f:write(line, '\n')
  end
  f:write('\n') -- trailing newline ensures last line is read by fd/rg
  f:close()

  cache[key] = out
  return out
end

--- Returns the path to a filtered .gitignore file (docs/ removed), or nil if
--- docs/ is not in .gitignore. Safe to call at any frequency — cached by mtime.
function M.ignore_file(cwd)
  local result = filter_gitignore(cwd or (vim.uv or vim.loop).cwd())
  if type(result) ~= 'string' then return nil end
  return result
end

return M
