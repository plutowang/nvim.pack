-- =============================================================================
-- LSP Configuration
-- =============================================================================

-- Neovim adds no title padding, so include it.
--- @param text string
--- @return string
local function float_title(text)
  return ' ' .. text .. ' '
end

-- lazydev: configure Lua LSP for Neovim config/plugin development
require('lazydev').setup {
  library = {
    { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
  },
}

-- Mason: install LSP servers & tools
require('mason').setup {}

-- LspAttach autocmd: keymaps and features on buffer attach
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('nvimpack-lsp-attach', { clear = true }),
  callback = function(event)
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buf = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Snacks is initialized at VimEnter, before any interactive keypress.
    local function snacks_picker(fn_name, opts)
      return function()
        Snacks.picker[fn_name](opts)
      end
    end

    map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
    map('grr', snacks_picker('lsp_references', { auto_confirm = false }), '[G]oto [R]eferences')
    map('gri', snacks_picker('lsp_implementations', { auto_confirm = false }), '[G]oto [I]mplementation')
    map('grd', snacks_picker('lsp_definitions', { auto_confirm = false }), '[G]oto [D]efinition')
    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
    map('gO', snacks_picker('lsp_symbols'), 'Open Document Symbols')
    map('gW', snacks_picker('lsp_workspace_symbols'), 'Open Workspace Symbols')
    map('grt', snacks_picker('lsp_type_definitions', { auto_confirm = false }), '[G]oto [T]ype Definition')

    -- Native floats routed through vim.lsp.buf.* opts (vim.lsp.with is deprecated).
    map('K', function()
      vim.lsp.buf.hover {
        border = 'rounded',
        title = float_title('Documentation'),
        title_pos = 'center',
        max_width = 80,
        max_height = 20,
      }
    end, 'Hover Documentation')

    -- <C-s> is Neovim's global default (defaults.lua:251); this buffer-local map
    -- shadows it to add float options, keeping the same key.
    map('<C-s>', function()
      vim.lsp.buf.signature_help {
        border = 'rounded',
        title = float_title('Signature'),
        title_pos = 'center',
        max_width = 80,
        max_height = 10,
      }
    end, 'Signature Help', 'i')

    local client = vim.lsp.get_client_by_id(event.data.client_id)

    -- Document highlight on cursor hold
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('nvimpack-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buf = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buf = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })
      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('nvimpack-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'nvimpack-lsp-highlight', buf = event2.buf }
        end,
      })
    end

    -- Inlay hints: enable on attach, toggle keymap
    if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
      map('<leader>th', function()
        local enabled = vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }
        vim.lsp.inlay_hint.enable(not enabled, { bufnr = event.buf })
      end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- Inlay hints: disable during insert mode to prevent race conditions where
-- rapid buffer edits (e.g. auto-completion) invalidate hint positions before
-- Neovim renders them, causing "Invalid 'col': out of range" errors.
-- vim.schedule on InsertLeave delays the re-enable until the buffer has settled.
vim.api.nvim_create_autocmd('InsertEnter', {
  group = vim.api.nvim_create_augroup('nvimpack-inlay-hints-insert', { clear = true }),
  callback = function(event)
    vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
  end,
})
vim.api.nvim_create_autocmd('InsertLeave', {
  group = 'nvimpack-inlay-hints-insert',
  callback = function(event)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
      end
    end)
  end,
})

-- Diagnostic display config
vim.diagnostic.config {
  severity_sort = true,
  float = {
    border = 'rounded',
    source = 'if_many',
    header = '',
    prefix = '',
    title = float_title('Diagnostics'),
    title_pos = 'center',
    max_width = 80,
    max_height = 20,
  },
  underline = true,
  signs = vim.g.have_nerd_font and {
    text = {
      [vim.diagnostic.severity.ERROR] = '󰅚 ',
      [vim.diagnostic.severity.WARN] = '󰀪 ',
      [vim.diagnostic.severity.INFO] = '󰋽 ',
      [vim.diagnostic.severity.HINT] = '󰌶 ',
    },
  } or {},
  virtual_text = false,
  virtual_lines = { current_line = true },
  update_in_insert = false,
}

-- LSP progress -> native terminal progress (OSC 9;4).
-- LSP emits LspProgress, not Progress; bridge directly to the terminal.
if vim.fn.has('nvim-0.12') == 1 then
  local group = vim.api.nvim_create_augroup('nvimpack-lsp-progress', { clear = true })
  local active = {} ---@type table<integer, table<string|integer, { percentage?: integer }>>
  local has_ui = #vim.api.nvim_list_uis() > 0
  local last_osc = nil

  local function send_osc(seq)
    if not has_ui or seq == last_osc then
      return
    end
    if pcall(vim.api.nvim_ui_send, seq) then
      last_osc = seq
    end
  end

  local function recompute()
    local max_percent = nil
    local any = false
    for _, tokens in pairs(active) do
      for _, token in pairs(tokens) do
        any = true
        if token.percentage then
          max_percent = math.max(max_percent or 0, token.percentage)
        end
      end
    end

    if not any then
      send_osc('\027]9;4;0;0\027\\')
    elseif max_percent then
      send_osc(string.format('\027]9;4;1;%d\027\\', max_percent))
    else
      send_osc('\027]9;4;3\027\\')
    end
  end

  local function sync_ui()
    has_ui = #vim.api.nvim_list_uis() > 0
    last_osc = nil
    recompute()
  end

  vim.api.nvim_create_autocmd('UIEnter', {
    group = group,
    callback = sync_ui,
  })

  vim.api.nvim_create_autocmd('UILeave', {
    group = group,
    callback = sync_ui,
  })

  vim.api.nvim_create_autocmd('LspProgress', {
    group = group,
    callback = function(ev)
      local data = ev.data
      local value = data.params.value
      local client_id = data.client_id
      local token_id = data.params.token
      if token_id == nil then
        return
      end
      local tokens = active[client_id]
      if not tokens then
        tokens = {}
        active[client_id] = tokens
      end

      if value.kind == 'end' then
        tokens[token_id] = nil
        if next(tokens) == nil then
          active[client_id] = nil
        end
      else
        local percentage = value.percentage
        if type(percentage) == 'number' then
          percentage = math.max(0, math.min(100, percentage))
        else
          percentage = nil
        end
        local token = tokens[token_id]
        if token then
          token.percentage = percentage
        else
          tokens[token_id] = { percentage = percentage }
        end
      end

      recompute()
    end,
  })

  vim.api.nvim_create_autocmd('LspDetach', {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or client:is_stopped() then
        active[ev.data.client_id] = nil
        recompute()
      end
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      last_osc = nil
      send_osc('\027]9;4;0;0\027\\')
    end,
  })
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = { 'documentation', 'detail', 'additionalTextEdits' },
}

-- ===========================================================================
-- LSP Server Helpers
-- ===========================================================================

-- Mason packages directory (used as fallback for probe locations)
local mason_dir = vim.fn.stdpath('data') .. '/mason/packages'

-- Resolves the nearest node_modules directory from root_dir.
-- Falls back to the Mason package's node_modules if not found in the project.
-- Used by angularls and astro for TypeScript/Angular probe locations.
local function get_probe_dir(root_dir, mason_package)
  local node_modules = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]
  if node_modules then
    return vim.fs.dirname(node_modules) .. '/node_modules'
  end
  -- Fallback: use Mason package's node_modules
  if mason_package then
    return mason_dir .. '/' .. mason_package .. '/node_modules'
  end
  return ''
end

-- Extracts @angular/core version from package.json (used by angularls).
-- Searches upward from root_dir to find the nearest package.json.
local function get_angular_core_version(root_dir)
  local node_modules = vim.fs.find('node_modules', { path = root_dir, upward = true })[1]
  local project_root = node_modules and vim.fs.dirname(node_modules)
  if not project_root then
    return ''
  end
  local package_json = project_root .. '/package.json'
  local stat = vim.uv.fs_stat(package_json)
  if not stat then
    return ''
  end
  local f = io.open(package_json, 'r')
  if not f then
    return ''
  end
  local contents = f:read('*a')
  f:close()
  local ok, json = pcall(vim.json.decode, contents)
  if not ok or not json then
    return ''
  end
  local version = json.dependencies and json.dependencies['@angular/core'] or nil
  return version and version:match('%d+%.%d+%.%d+') or ''
end

local servers = {
  -- angularls is handled separately below via vim.lsp.start() autocmd
  -- because it requires dynamic cmd construction (probe locations, Angular version)
  -- that cannot be done via vim.lsp.config/enable (root_dir config updates
  -- don't take effect for the current server start).
  graphql = {
    cmd = { 'graphql-lsp', 'server', '-m', 'stream' },
    filetypes = { 'graphql', 'typescriptreact', 'javascriptreact' },
    root_markers = { '.graphqlrc', '.graphqlrc.json', '.graphql.config.*', 'graphql.config.*' },
  },
  astro = {
    cmd = { 'astro-ls', '--stdio' },
    filetypes = { 'astro' },
    root_markers = { 'package.json', 'tsconfig.json', '.git' },
  },
  gopls = {
    cmd = { 'gopls' },
    filetypes = { 'go', 'gomod', 'gowork', 'gotmpl' },
    root_markers = { 'go.work', 'go.mod', '.git' },
    single_file_support = true,
    settings = {
      gopls = {
        templateExtensions = { 'tmpl', 'gohtml' },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        gofumpt = true,
        codelenses = {
          gc_details = false,
          generate = true,
          regenerate_cgo = true,
          run_govulncheck = true,
          test = true,
          tidy = true,
          upgrade_dependency = true,
          vendor = true,
        },
        usePlaceholders = true,
        completeUnimported = true,
        staticcheck = true,
        directoryFilters = { '-.git', '-node_modules' },
      },
    },
  },
  html = {
    cmd = { 'vscode-html-language-server', '--stdio' },
    filetypes = { 'html', 'templ' },
    root_markers = { 'package.json', '.git' },
    single_file_support = true,
  },
  -- rust_analyzer is intentionally excluded: rustaceanvim (in tools.lua, fn = 'testing')
  -- manages its own rust-analyzer client. Having both would cause duplicate
  -- LSP clients and conflicting diagnostics on Rust buffers.
  tailwindcss = {
    cmd = { 'tailwindcss-language-server', '--stdio' },
    filetypes = {
      'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact',
      'vue', 'svelte', 'astro', 'templ', 'php', 'blade', 'erb', 'hamlet', 'heex',
      'surface', 'mustache', 'handlebars', 'hbs', 'mjml', 'ejs', 'twig', 'nunjucks',
      'liquid', 'aspnetcorerazor',
    },
    root_markers = { 'tailwind.config.*', 'postcss.config.*', '.postcssrc', '.postcssrc.*' },
  },
  ts_ls = {
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
    single_file_support = true,
  },
  zls = {
    cmd = { 'zls' },
    filetypes = { 'zig', 'zon' },
    root_markers = { 'zls.json', 'build.zig', '.git' },
    single_file_support = true,
    settings = {
      zls = {
        force_autofix = true,
        enable_build_on_save = true,
        enable_inlay_hints = true,
        inlay_hints_show_builtin = true,
        inlay_hints_exclude_single_argument = true,
        inlay_hints_hide_redundant_param_names = false,
        inlay_hints_hide_redundant_param_names_last_token = true,
        inlay_hints_show_parameter_name = true,
        inlay_hints_show_variable_type_hints = true,
        enable_argument_placeholders = true,
        highlight_global_var_declarations = true,
        warn_style = true,
        skip_std_references = true,
      },
    },
  },
  lua_ls = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    single_file_support = true,
    settings = {
      Lua = {
        completion = { callSnippet = 'Replace' },
      },
    },
  },
  gitlab_ci_ls = {
    cmd = { 'gitlab-ci-ls' },
    filetypes = { 'yaml.gitlab' },
    root_markers = { '.gitlab', '.git' },
    single_file_support = true,
  },
}

-- Mapping: lspconfig name → Mason package name
-- Used to install LSP servers via mason-tool-installer (since mason-lspconfig is removed).
-- When adding a new server, add an entry here AND in the `servers` table above.
local lsp_to_mason = {
  angularls = 'angular-language-server',
  graphql = 'graphql-language-service-cli',
  astro = 'astro-language-server',
  gopls = 'gopls',
  html = 'html-lsp',
  tailwindcss = 'tailwindcss-language-server',
  ts_ls = 'typescript-language-server',
  zls = 'zls',
  lua_ls = 'lua-language-server',
  gitlab_ci_ls = 'gitlab-ci-ls',
}

local ensure_installed = vim.tbl_values(lsp_to_mason)
vim.list_extend(ensure_installed, {
  'stylua',
  'prettier',
  'ast-grep',
})

require('mason-tool-installer').setup {
  ensure_installed = ensure_installed,
  integrations = {
    ['mason-nvim-dap'] = false,
    ['mason-lspconfig'] = false,
  },
}

for server_name, server_config in pairs(servers) do
  server_config.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server_config.capabilities or {})
  vim.lsp.config(server_name, server_config)
  vim.lsp.enable(server_name)
end

-- =============================================================================
-- angularls: manual start via vim.lsp.start()
-- =============================================================================
-- angularls requires dynamic cmd construction (--tsProbeLocations,
-- --ngProbeLocations, --angularCoreVersion) resolved from the project's
-- node_modules. vim.lsp.enable/vim.lsp.config cannot be used because
-- root_dir config updates don't take effect for the current server start.
-- Instead, we start manually via FileType autocmd + vim.lsp.start().
--
-- Pattern 2 rule: always verify technology presence before vim.lsp.start().
-- root markers like 'project.json' and 'nx.json' are too broad — they exist
-- in non-Angular Nx workspaces. get_angular_core_version() already reads
-- package.json; reuse its result as a guard (empty = no @angular/core).
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('nvimpack-angularls', { clear = true }),
  pattern = { 'typescript', 'htmlangular' },
  callback = function(ev)
    local root = vim.fs.root(ev.buf, { 'angular.json', 'project.json', 'nx.json' })
    if not root then return end
    -- Guard: bail if @angular/core is absent (e.g. non-Angular Nx monorepo).
    -- get_angular_core_version reads package.json — reuse it as a presence
    -- check so we don't add a second package.json read.
    local angular_core_version = get_angular_core_version(root)
    if angular_core_version == '' then return end
    local probe_dir = get_probe_dir(root, 'angular-language-server')
    vim.lsp.start({
      name = 'angularls',
      cmd = {
        vim.fn.exepath('ngserver'),
        '--stdio',
        '--tsProbeLocations', probe_dir,
        '--ngProbeLocations', probe_dir,
        '--angularCoreVersion', angular_core_version,
      },
      root_dir = root,
      capabilities = capabilities,
    })
  end,
})

-- =============================================================================
-- Module exports (for fn-triggered pack entries)
-- =============================================================================

local M = {}

--- No-op: rustaceanvim self-configures via ftplugin/rust.lua when packadd'd.
-- This function exists so the pack engine can reference mod = 'lsp', fn = 'rustacean'.
function M.rustacean() end

return M
