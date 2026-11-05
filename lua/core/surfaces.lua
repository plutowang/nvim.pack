-- Derives floating-window colours from the active colorscheme on ColorScheme:
-- semantic palette first (catppuccin), RGB math as fallback.

local M = {}

local T1_STEP = { light = 0.035, dark = 0.045 } -- tier 1 off the canvas (math path only)
local T2_STEP = 0.035 -- tier 2 off tier 1
local SEL_STEP = 0.055 -- selection band off its surface
local BORDER_MIX = 0.22 -- surface -> separator blend for the hairline
local THUMB_MIX = 0.35 -- scrollbar thumb off the surface
local CR_MIN, CR_MAX = 1.02, 1.30 -- accepted subtlety band for a semantic tier 1

-- The only literals here: seeds for a canvas that has no background at all.
local CANVAS_FALLBACK = { light = 0xeff1f5, dark = 0x1e1e2e }

if vim.g.neovide then
  vim.g.neovide_floating_shadow = true
  vim.g.neovide_floating_z_height = 12
  vim.g.neovide_light_angle_degrees = 45
  vim.g.neovide_light_radius = 6
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
end

local function channels(hex)
  return math.floor(hex / 65536) % 256, math.floor(hex / 256) % 256, hex % 256
end

local function pack(r, g, b)
  return r * 65536 + g * 256 + b
end

--- sRGB-space blend, rounded half up.
local function mix(a, b, t)
  local ar, ag, ab = channels(a)
  local br, bg, bb = channels(b)
  return pack(
    math.floor(ar + (br - ar) * t + 0.5),
    math.floor(ag + (bg - ag) * t + 0.5),
    math.floor(ab + (bb - ab) * t + 0.5)
  )
end

local function to_hex(n)
  return string.format('#%06x', n)
end

local function srgb_to_linear(c)
  c = c / 255
  return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex)
  local r, g, b = channels(hex)
  return 0.2126 * srgb_to_linear(r) + 0.7152 * srgb_to_linear(g) + 0.0722 * srgb_to_linear(b)
end

--- Symmetric WCAG ratio, 1..21.
local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  if la < lb then
    la, lb = lb, la
  end
  return (la + 0.05) / (lb + 0.05)
end

--- Effective attribute of a group. Never creates the group.
local function hl(name, attr)
  local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false, create = false })
  if not ok or type(def) ~= 'table' then
    return nil
  end
  return def[attr]
end

local function parse_hex(s)
  if type(s) ~= 'string' then
    return nil
  end
  return tonumber((s:gsub('^#', '')), 16)
end

--- Compute every surface colour without writing any highlight.
function M.derive()
  local dark = vim.o.background == 'dark'
  local mode = dark and 'dark' or 'light'
  local extreme = dark and 0xffffff or 0x000000

  local canvas_bg = hl('Normal', 'bg') or hl('NormalNC', 'bg') or CANVAS_FALLBACK[mode]
  local canvas_fg = hl('Normal', 'fg') or hl('NormalNC', 'fg') or extreme

  local text = hl('NormalFloat', 'fg') or canvas_fg
  local muted = hl('Comment', 'fg') or hl('NonText', 'fg') or canvas_fg
  local separator = hl('WinSeparator', 'fg') or hl('NonText', 'fg') or muted
  local accent = hl('Function', 'fg') or hl('Special', 'fg') or hl('Statement', 'fg') or canvas_fg

  local function step(color, t)
    return mix(color, extreme, t)
  end

  -- Semantic tier 1 only while it stays subtle. `g:colors_name` carries the
  -- flavour suffix (e.g. 'catppuccin-latte').
  local tier1
  local palette
  if (vim.g.colors_name or ''):match('^catppuccin') then
    local ok, palettes = pcall(require, 'catppuccin.palettes')
    if ok then
      local ok2, p = pcall(palettes.get_palette)
      if ok2 and type(p) == 'table' then
        palette = p
        local cand = parse_hex(dark and p.surface0 or p.mantle)
        if cand then
          local cr = contrast(cand, canvas_bg)
          if cr >= CR_MIN and cr <= CR_MAX then
            tier1 = cand
          end
        end
      end
    end
  end
  tier1 = tier1 or step(canvas_bg, T1_STEP[mode])

  local tier2 = step(tier1, T2_STEP)
  local sel1 = step(tier1, SEL_STEP)
  local sel2 = step(tier2, SEL_STEP)
  local border1 = mix(tier1, separator, BORDER_MIX)
  local border2 = mix(tier2, separator, BORDER_MIX)
  local thumb = mix(tier1, separator, THUMB_MIX)

  -- Title text uses the statusline NORMAL badge colour (heirline.lua:202).
  local title_bg = palette and parse_hex(palette.lavender) or accent

  return {
    background = mode,
    canvas_bg = to_hex(canvas_bg),
    canvas_fg = to_hex(canvas_fg),
    text = to_hex(text),
    muted = to_hex(muted),
    separator = to_hex(separator),
    accent = to_hex(accent),
    tier1 = to_hex(tier1),
    tier2 = to_hex(tier2),
    border1 = to_hex(border1),
    border2 = to_hex(border2),
    sel1 = to_hex(sel1),
    sel2 = to_hex(sel2),
    thumb = to_hex(thumb),
    title_bg = to_hex(title_bg),
  }
end

--- Keep the theme's fg/styles, replace only the background.
local function relayer(name, bg)
  local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false, create = false })
  if not ok or type(def) ~= 'table' or next(def) == nil then
    return
  end
  def.bg = bg
  pcall(vim.api.nvim_set_hl, 0, name, def)
end

-- Only groups whose upstream default disagrees; the comment names the culprit.
-- Groups that already link to the right target are intentionally absent.
local ALIASES = {
  BlinkCmpMenuBorder = 'FloatBorder', -- blink/catppuccin: Pmenu
  BlinkCmpMenuSelection = 'PmenuSel', -- catppuccin: bg = surface1
  BlinkCmpScrollBarGutter = 'PmenuSbar', -- catppuccin: bg = surface1
  BlinkCmpScrollBarThumb = 'PmenuThumb', -- catppuccin: bg = overlay0
  BlinkCmpDoc = 'FloatDoc', -- catppuccin: NormalFloat (tier 1)
  BlinkCmpDocBorder = 'FloatDocBorder', -- catppuccin: NormalFloat
  SnacksNormal = 'NormalFloat', -- catppuccin: Normal
  SnacksInputNormal = 'NormalFloat', -- snacks: Normal
  SnacksInputBorder = 'FloatBorder', -- snacks: DiagnosticInfo
  SnacksInputTitle = 'FloatTitle', -- snacks: DiagnosticInfo
  -- which-key sets these from a vim.schedule_wrap'd load(), so pin them here.
  WhichKeyNormal = 'NormalFloat',
  WhichKeyTitle = 'FloatTitle',
}

function M.apply()
  local d = M.derive()
  local t1, t2 = parse_hex(d.tier1), parse_hex(d.tier2)
  local b1, b2 = parse_hex(d.border1), parse_hex(d.border2)
  local s1, s2 = parse_hex(d.sel1), parse_hex(d.sel2)
  local text, accent = parse_hex(d.text), parse_hex(d.accent)
  local muted, sep, thumb = parse_hex(d.muted), parse_hex(d.separator), parse_hex(d.thumb)
  local title_bg = parse_hex(d.title_bg)

  local set = vim.api.nvim_set_hl

  set(0, 'NormalFloat', { bg = t1, fg = text })
  set(0, 'FloatBorder', { bg = t1, fg = b1 })
  set(0, 'Pmenu', { bg = t1, fg = text })
  set(0, 'PmenuBorder', { bg = t1, fg = b1 })
  set(0, 'PmenuSel', { bg = s1, fg = text, bold = true })
  set(0, 'PmenuSbar', { bg = t1 })
  set(0, 'PmenuThumb', { bg = thumb })
  set(0, 'PmenuMatch', { fg = accent })
  set(0, 'PmenuMatchSel', { fg = accent, bold = true })

  set(0, 'FloatDoc', { bg = t2, fg = text })
  set(0, 'FloatDocBorder', { bg = t2, fg = b2 })
  set(0, 'FloatDocTitle', { bg = t2, fg = title_bg, bold = true })
  set(0, 'BlinkCmpDocSeparator', { fg = sep, bg = t2 })
  set(0, 'BlinkCmpDocCursorLine', { bg = s2 })

  set(0, 'FloatTitle', { bg = t1, fg = title_bg, bold = true })
  set(0, 'FloatFooter', { bg = t1, fg = muted, italic = true })

  for name, target in pairs(ALIASES) do
    set(0, name, { link = target })
  end

  relayer('PmenuKind', t1)
  relayer('PmenuKindSel', s1)
  relayer('PmenuExtraSel', s1)
end

--- Register the hook without applying eagerly: at attach time the previous
--- theme is still active, so an eager apply would derive from it.
function M.attach()
  local group = vim.api.nvim_create_augroup('nvimpack-surfaces', { clear = true })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = group,
    callback = function()
      M.apply()
    end,
  })
end

return M
