require("config.lazy")
local robloxLsp = require("roblox_luau_lsp")

vim.lsp.config["roblox-luau-lsp"] = robloxLsp 
vim.lsp.enable("roblox-luau-lsp")

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.wo.number = true
vim.wo.relativenumber = true
vim.g.mapleader = " "

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

vim.g.undotree_WindowLayout = 2
vim.keymap.set('n', '<leader>u', ':UndotreeShow<CR>:UndotreeFocus<CR>', { desc = 'Toggle undo tree' })
