require("config.lazy")
require("map")
require("lsp_configs")

-- Disable optional (unused) providers
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0

-- Enable useful options
vim.wo.number = true
vim.wo.relativenumber = true

-- Auto trim whitespace
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
	pattern = { "*" },
	command = [[%s/\s\+$//e]],
})

-- Full screen the help pages
vim.api.nvim_create_autocmd("FileType", {
	pattern = "help",
	callback = function()
		vim.cmd("only")
	end,
})

-- TODO: Tag plugin versions and neovim version
