-- Catppuccin colorscheme

local themes = {
  latte = { flavour = 'latte', background = 'light' },
  nge = {
    flavour = 'mocha',
    background = 'dark',
    color_overrides = {
      mocha = {
        base = '#181825',
        mantle = '#11111b',
        surface0 = '#2a2a37',
        lavender = '#b4befe',
        green = '#a6e3a1',
        mauve = '#cba6f7',
        peach = '#fab387',
      },
    },
  },
}

local function get_active_theme_name()
  return vim.g.current_color_theme or 'latte'
end

local function set_active_theme(theme_name)
  vim.g.current_color_theme = theme_name
  vim.schedule(function()
    if vim.v.this_session ~= '' then
      vim.cmd('mksession!')
    end
  end)
end

local theme_colors = {
  get_active_theme = function()
    return get_active_theme_name()
  end,

  get_theme_based_value = function(nge_value, latte_value)
    return get_active_theme_name() == 'nge' and nge_value or latte_value
  end,

  get_badge_colors = function(component)
    local is_nge = get_active_theme_name() == 'nge'
    if component == 'theme' then
      return is_nge and { fg = '#11111b', bg = '#b4befe', bold = true }
                    or { fg = '#4c4f69', bg = '#f5c2e7', bold = true }
    else
      return is_nge and { fg = '#11111b', bg = '#a6e3a1', bold = true }
                    or { fg = '#eff1f5', bg = '#8839ef', bold = true }
    end
  end,
}

_G.theme_colors = theme_colors

local function toggle_between_themes()
  local current = get_active_theme_name()
  local new_theme = current == 'latte' and 'nge' or 'latte'
  set_active_theme(new_theme)

  local theme_config = themes[new_theme]
  vim.opt.background = theme_config.background

  require('catppuccin').setup {
    flavour = theme_config.flavour,
    term_colors = false,
    color_overrides = theme_config.color_overrides,
  }

  vim.cmd('colorscheme catppuccin')

  -- Reapply terminal colors (Catppuccin term_colors reset them)
  vim.g.terminal_color_0  = '#5c5f77'
  vim.g.terminal_color_1  = '#d20f39'
  vim.g.terminal_color_2  = '#40a02b'
  vim.g.terminal_color_3  = '#df8e1d'
  vim.g.terminal_color_4  = '#1e66f5'
  vim.g.terminal_color_5  = '#8839ef'
  vim.g.terminal_color_6  = '#179299'
  vim.g.terminal_color_7  = '#7c7f93'  -- overlay2 (darker)
  vim.g.terminal_color_8  = '#6c6f85'
  vim.g.terminal_color_9  = '#d20f39'
  vim.g.terminal_color_10 = '#40a02b'
  vim.g.terminal_color_11 = '#fe640b'  -- peach (darker)
  vim.g.terminal_color_12 = '#1e66f5'
  vim.g.terminal_color_13 = '#8839ef'
  vim.g.terminal_color_14 = '#179299'
  vim.g.terminal_color_15 = '#4c4f69'

  if package.loaded['heirline'] then
    require('heirline').reset_highlights()
    vim.cmd('redrawstatus')
  end
end

_G.toggle_color_theme = toggle_between_themes

-- UI tweaks
vim.opt.shortmess:append 'q'

local current_theme = get_active_theme_name()
local theme_config = themes[current_theme]

vim.opt.background = theme_config.background

require('catppuccin').setup {
  flavour = theme_config.flavour,
  term_colors = false,
  dim_inactive = {
    enabled = true,
    shade = current_theme == 'latte' and 'light' or 'dark',
    percentage = 0.12,
  },
  color_overrides = theme_config.color_overrides,
  styles = {
    comments = { 'italic' },
    conditionals = { 'italic' },
    functions = { 'bold' },
    keywords = { 'bold' },
    types = { 'italic' },
  },
  integrations = {
    cmp = true,
    gitsigns = true,
    neo_tree = true,
    treesitter = true,
    treesitter_context = true,
    notify = true,
    mason = true,
    telescope = { enabled = true, style = 'nvchad' },
    which_key = true,
    flash = true,
    lsp_trouble = true,
    indent_blankline = { enabled = true, scope_color = 'lavender' },
    dap = { enabled = true, enable_ui = true },
    render_markdown = true,
    blink_cmp = true,
    neotest = true,
  },
  custom_highlights = function(colors)
    return {
      CursorLine = { bg = colors.surface0 },
      CursorColumn = { bg = colors.surface0 },
      ColorColumn = { bg = colors.surface0 },
      WinSeparator = { fg = colors.overlay0, bg = colors.base },
      Folded = { style = { 'italic', 'bold' } },
      LineNr = { fg = colors.overlay0 },
      CursorLineNr = { fg = colors.mauve, style = { 'bold' } },
      NormalFloat = { bg = colors.mantle, fg = colors.text, blend = 10 },
      FloatBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      FloatTitle = { bg = colors.mantle, fg = colors.lavender, style = { 'bold' }, blend = 8 },
      FloatFooter = { bg = colors.mantle, fg = colors.overlay0, style = { 'italic' }, blend = 8 },
      DiagnosticHint = { fg = colors.teal },
      IblIndent = { fg = colors.surface0 },
      IblScope = { fg = colors.surface2 },
      CmpMenu = { bg = colors.mantle, fg = colors.text, blend = 10 },
      CmpMenuBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      CmpMenuSel = { bg = colors.surface0, fg = colors.text, style = { 'bold' } },
      CmpDocumentation = { bg = colors.mantle, fg = colors.text, blend = 10 },
      CmpDocumentationBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      CmpDocumentationCursorLine = { bg = colors.surface0 },
      CmpSignatureHelp = { bg = colors.mantle, fg = colors.text, blend = 10 },
      CmpSignatureHelpBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      LspReferenceText = { bg = colors.surface1, style = { 'bold' } },
      LspReferenceRead = { bg = colors.surface1, style = { 'bold' } },
      LspReferenceWrite = { bg = colors.peach, fg = colors.base, style = { 'bold' } },
      TelescopeNormal = { bg = colors.mantle, fg = colors.text, blend = 10 },
      TelescopeBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      TelescopeTitle = { bg = colors.lavender, fg = colors.mantle, style = { 'bold' }, blend = 8 },
      TelescopeSelection = { bg = colors.surface0, fg = colors.text, style = { 'bold' } },
      TelescopeSelectionCaret = { fg = colors.flamingo },
      TelescopeMatching = { fg = colors.blue, style = { 'bold' } },
      TelescopePromptPrefix = { fg = colors.flamingo },
      TelescopePromptCounter = { fg = colors.overlay1 },
      WhichKey = { fg = colors.lavender, style = { 'bold' } },
      WhichKeyGroup = { fg = colors.lavender },
      WhichKeyDesc = { fg = colors.lavender },
      WhichKeySeparator = { fg = colors.overlay1 },
      WhichKeyFloat = { bg = colors.mantle, blend = 10 },
      WhichKeyBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      NeoTreeNormal = { bg = colors.mantle, fg = colors.text },
      NeoTreeNormalNC = { bg = colors.mantle, fg = colors.text },
      NeoTreeWinSeparator = { bg = colors.base, fg = colors.base },
      NeoTreeFloatBorder = { bg = colors.mantle, fg = colors.overlay0, blend = 8 },
      NeoTreeFloatTitle = { bg = colors.mantle, fg = colors.lavender, style = { 'bold' }, blend = 8 },
      MasonNormal = { bg = colors.mantle, fg = colors.text, blend = 10 },
      MasonHeader = { bg = colors.blue, fg = colors.mantle, style = { 'bold' } },
      MasonHeaderSecondary = { bg = colors.lavender, fg = colors.mantle, style = { 'bold' } },
      MasonHighlight = { fg = colors.blue },
      MasonHighlightBlock = { bg = colors.blue, fg = colors.mantle },
      MasonHighlightBlockBold = { bg = colors.blue, fg = colors.mantle, style = { 'bold' } },
      MasonHighlightSecondary = { fg = colors.lavender },
      MasonHighlightBlockSecondary = { bg = colors.lavender, fg = colors.mantle },
      MasonHighlightBlockBoldSecondary = { bg = colors.lavender, fg = colors.mantle, style = { 'bold' } },
      MasonMuted = { fg = colors.overlay1 },
      MasonMutedBlock = { bg = colors.overlay1, fg = colors.mantle },
      MasonMutedBlockBold = { bg = colors.overlay1, fg = colors.mantle, style = { 'bold' } },
      ['@variable.angular'] = { fg = colors.mauve, style = { 'italic' } },
      NeotestPassed = { fg = colors.green, style = { 'bold' } },
      NeotestFailed = { fg = colors.red, style = { 'bold' } },
      NeotestRunning = { fg = colors.yellow, style = { 'bold' } },
      NeotestSkipped = { fg = colors.blue, style = { 'bold' } },
    }
  end,
}
vim.cmd.colorscheme 'catppuccin'

-- Terminal color palette — Catppuccin Latte (light-background compatible)
-- Set AFTER colorscheme so Catppuccin's compiled term_colors takes a back seat.
vim.g.terminal_color_0  = '#5c5f77'
vim.g.terminal_color_1  = '#d20f39'
vim.g.terminal_color_2  = '#40a02b'
vim.g.terminal_color_3  = '#df8e1d'
vim.g.terminal_color_4  = '#1e66f5'
vim.g.terminal_color_5  = '#8839ef'
vim.g.terminal_color_6  = '#179299'
vim.g.terminal_color_7  = '#7c7f93'  -- overlay2 (darker)
vim.g.terminal_color_8  = '#6c6f85'
vim.g.terminal_color_9  = '#d20f39'
vim.g.terminal_color_10 = '#40a02b'
vim.g.terminal_color_11 = '#fe640b'  -- peach (darker)
vim.g.terminal_color_12 = '#1e66f5'
vim.g.terminal_color_13 = '#8839ef'
vim.g.terminal_color_14 = '#179299'
vim.g.terminal_color_15 = '#4c4f69'
