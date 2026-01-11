vim.g.mapleader = " "

-- Copy to clipboard
vim.keymap.set("n", "<leader>y", '"+y')

-- Undotree binds
vim.keymap.set("n", "<leader>u", ":UndotreeShow<CR>:UndotreeFocus<CR>", { desc = "Toggle undo tree" })

-- Telescope binds
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.find_files, { desc = "Telescope find git files" })
vim.keymap.set("n", "<leader>fG", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

-- dap binds
local dap = require("dap")
vim.keymap.set("n", "<Leader>b", function()
	dap.toggle_breakpoint()
end)
vim.keymap.set("n", "<F5>", function()
	dap.continue()
end)
vim.keymap.set("n", "<F10>", function()
	dap.step_over()
end)
vim.keymap.set("n", "<F11>", function()
	dap.step_into()
end)
vim.keymap.set("n", "<F12>", function()
	dap.step_out()
end)
