local M = {}

local defaultSettings = {
	-- The width of the UI window
	windowWidth = 50,
	-- Options in this block are the default independent of language
	default = {
		-- Check the output of `gwatch --help` for specific information about flags
		eventMask = "write",
		mode = "kill",
		patterns = "**",
		callback = require("gwatch.ui").write_to_term,
		-- %e and %f respectively expand to the event, and the file it affected
		command = "echo %e %f",
	},
}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", {}, M.options or {}, defaultSettings, options or {})
end

M.setup()

return M
