return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	branch = "main",
	build = ":TSUpdate",
	-- FIXME: Update file types by what's needed
	config = function()
		require("nvim-treesitter").install({ "javascript", "lua", "python" })
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "lua", "javascript", "python" },
			callback = function()
				vim.treesitter.start()
			end,
		})
	end,
}
