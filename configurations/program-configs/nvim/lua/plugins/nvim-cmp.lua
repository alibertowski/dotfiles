return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"L3MON4D3/LuaSnip",
		"saadparwaiz1/cmp_luasnip"
	},
	opts = {
		sources = {
			{ name = 'nvim_lsp' },
			{ name = 'luasnip' },
		},
		snippet = {
			expand = function(args)
				require('luasnip').lsp_expand(args.body)
			end
		}
	}
}
