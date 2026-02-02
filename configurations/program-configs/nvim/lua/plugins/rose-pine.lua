-- lua/plugins/rose-pine.lua
return {
	"rose-pine/neovim",
	priority = 1000,
	name = "rose-pine",
	opts = {
		dark_variant = "moon",
		styles = {
			transparency = true,
		},
	},
	config = function(_, opts)
		require("rose-pine").setup(opts)
		vim.cmd("colorscheme rose-pine")
	end,
}
