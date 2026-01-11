return {
	"mbbill/undotree",
	init = function(_)
		vim.g.undotree_WindowLayout = 2

		local is_windows = vim.fn.has("win32")
		if is_windows == 1 then
			vim.g.undotree_DiffCommand = "C:\\Progra~1\\Git\\usr\\bin\\diff.exe" -- FIXME: If on windows, make sure this path is correct. (Git Bash contains diff.exe)
		end
	end,
	cmd = { "UndotreeShow" },
}
