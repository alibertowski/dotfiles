return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"igorlfs/nvim-dap-view",
	},
	config = function()
		vim.fn.sign_define("DapBreakpoint", { text = "⬤", texthl = "DapBreakpoint", linehl = "", numhl = "" })
		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF5555" })

		-- FIXME: Update/comment any needed configurations
		local dap = require("dap")
		dap.adapters["pwa-node"] = {
			type = "server",
			host = "localhost",
			port = "${port}",
			executable = {
				command = "node",
				-- FIXME: Make sure to update this path to point to your installation
				args = { "/home/retro/Downloads/js-debug/src/dapDebugServer.js", "${port}" },
			},
		}

		dap.configurations.javascript = {
			{
				type = "pwa-node",
				request = "launch",
				name = "Launch file",
				program = "index.js",
				cwd = "${workspaceFolder}",
			},
		}
	end,
}
