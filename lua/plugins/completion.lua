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
		ghost_text = {
			enabled = true,
			show_without_selection = true,
		},
		documentation = {
			auto_show = true,
			auto_show_delay_ms = 500,
			window = {
				border = "rounded",
				-- unset on purpose: blink's default maps BlinkCmpDoc* and keeps Search:None
				winblend = 10,
				scrollbar = true,
				max_width = 80,
				max_height = 20,
			},
		},
		menu = {
			border = "rounded",
			-- unset on purpose: blink's default maps BlinkCmpMenu* and keeps Search:None
			winblend = 10,
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
		sorts = { "exact", "score", "sort_text", "label" },
	},

	signature = {
		enabled = false,
	},
})
