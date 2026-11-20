return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	branch = "main",
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({ "lua", "javascript", "python", "c", "cpp", "json" })
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "lua", "javascript", "python", "c", "cpp", "json" },
			callback = function()
				vim.treesitter.start()
			end,
		})
	end,
}
