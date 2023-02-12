local M = {}
local ui = require("gwatch.ui")

local defaultSettings = {
	windowWidth = 50,
	default = {
		eventMask = "write",
		mode = "kill",
		patterns = "**",
		callback = ui.write_to_term,
		command = "echo %e %f",
	},
	lang = {
		go = {
			patterns = "**.go",
			command = "go build -o ./out .; ./out",
			callback = function(s)
				ui.write_to_term(s)
			end,
		},
		rust = {
			patterns = "**.rs",
			command = "cargo run",
		},
		lua = {
			patterns = "**.lua",
			callback = vim.notify,
			command = "echo %e %f",
		},
	},
}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, defaultSettings, options or {})
end

M.setup()

return M
