local M = {}

local defaults = {
	eventMask = "write",
	mode = "kill",
	command = {
		go = "go run .",
		rust = "cargo run",
		default = nil,
	},
	patterns = ".",
  windowWidth = 30,
}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, defaults, options or {})
end

M.setup()

return M
