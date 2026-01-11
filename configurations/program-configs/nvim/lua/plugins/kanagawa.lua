return {
	"rebelot/kanagawa.nvim",
	priority = 1000,
	config = function()
		local kanagawa = require("kanagawa")
		kanagawa.setup({ transparent = true })
		kanagawa.load("dragon")
	end,
}
