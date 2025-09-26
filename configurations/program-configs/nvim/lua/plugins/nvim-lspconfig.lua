return {
	"neovim/nvim-lspconfig",
	config = function()
		vim.lsp.enable('rust_analyzer')
	end,
}
