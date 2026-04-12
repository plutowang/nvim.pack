-- Blink.cmp completion engine + native vim.snippet

require("blink.cmp").setup({
	keymap = {
		preset = "default",
		["<Tab>"] = { "snippet_forward", "fallback" },
		["<S-Tab>"] = { "snippet_backward", "fallback" },
		-- ['<CR>'] = { 'accept', 'fallback' },
	},

	appearance = {
		nerd_font_variant = "mono",
		kind_icons = {
			Text = "󰉿",
			Method = "󰆧",
			Function = "󰊕",
			Constructor = "",
			Field = "󰜢",
			Variable = "󰀫",
			Class = "󰠱",
			Interface = "",
			Module = "",
			Property = "󰜢",
			Unit = "󰑭",
			Value = "󰎠",
			Enum = "",
			Keyword = "󰌋",
			Snippet = "",
			Color = "󰏘",
			File = "󰈙",
			Reference = "󰈇",
			Folder = "󰉋",
			EnumMember = "",
			Constant = "󰏿",
			Struct = "󰙅",
			Event = "",
			Operator = "󰆕",
			TypeParameter = "",
		},
	},

	completion = {
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 500,
			window = {
				border = "rounded",
				winhighlight = "Normal:CmpDocumentation,FloatBorder:CmpDocumentationBorder,CursorLine:CmpDocumentationCursorLine,Search:None",
				scrollbar = true,
				max_width = 80,
				max_height = 20,
			},
		},
		menu = {
			border = "rounded",
			winhighlight = "Normal:CmpMenu,FloatBorder:CmpMenuBorder,CursorLine:PmenuSel,Search:None",
			max_height = 15,
			scrolloff = 2,
			scrollbar = true,
			draw = {
				treesitter = { "lsp" },
				columns = {
					{ "kind_icon", "label", gap = 1 },
					{ "label_description", gap = 1 },
					{ "source_name" },
				},
				components = {
					kind_icon = {
						ellipsis = false,
						text = function(ctx)
							return ctx.kind_icon .. " "
						end,
						highlight = function(ctx)
							return "CmpItemKind" .. ctx.kind
						end,
					},
					label = {
						width = { fill = true, max = 60 },
						text = function(ctx)
							return ctx.label .. ctx.label_detail
						end,
						highlight = function(ctx)
							local highlights = {
								nvim_lsp = "CmpItemAbbrMatch",
								buffer = "CmpItemAbbrMatchFuzzy",
								path = "CmpItemAbbrMatchFuzzy",
							}
							return highlights[ctx.source_name] or "CmpItemAbbr"
						end,
					},
					label_description = {
						width = { max = 30 },
						text = function(ctx)
							return ctx.label_description
						end,
						highlight = "CmpItemMenu",
					},
				},
			},
		},
	},

	sources = {
		default = { "lsp", "path", "snippets", "buffer" },
		per_filetype = {
			lua = { "lazydev", "lsp", "path", "snippets", "buffer" },
		},
		providers = {
			lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
		},
	},

	snippets = { preset = "default" },

	fuzzy = {
		implementation = "prefer_rust",
		sorts = { "label", "kind", "score" },
	},

	signature = {
		enabled = false,
	},
})
