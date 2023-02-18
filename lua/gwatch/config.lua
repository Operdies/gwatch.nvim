local M = {}

local defaultSettings = {
	-- The width of the UI window
	["window width"] = 80,
	["window height"] = 20,
	["window position"] = "right",
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

local configOptions = {}
local sessionOptions = {}

function M.setup(options)
	configOptions = vim.tbl_deep_extend("force", {}, defaultSettings, options or {})
end

function M.update(options)
	sessionOptions = vim.tbl_deep_extend("force", {}, configOptions, options or {})
	return M.options()
end

function M.options()
	return vim.tbl_deep_extend("force", {}, defaultSettings, configOptions or {}, sessionOptions or {})
end

function M.overrides()
	return sessionOptions
end

local settingsTree = {
	command = { type = "input", prompt = "Set command to what?", default = nil },
	["window width"] = { type = "input", prompt = "Set width to what?", default = "80" },
	["window height"] = { type = "input", prompt = "Set height to what?", default = "20" },
	mode = { type = "select", options = { "block", "kill", "concurrent" } },
	["window position"] = { type = "select", options = { "left", "right", "above", "below" } },
}

local function maybeRestart()
	require("gwatch").maybeRestart()
end

M.settings = function()
	local keyset = {}
	for k, _ in pairs(settingsTree) do
		keyset[#keyset + 1] = k
	end
	vim.ui.select(
		keyset,
		{ prompt = "Update which setting?", telescope = require("telescope.themes").get_cursor() },
		function(name)
			local settings = settingsTree[name]
			if settings == nil then
				return
			end
			if settings["type"] == "input" then
				vim.ui.input(settings, function(value)
					if value == "" then
						value = nil
					end
					sessionOptions[name] = value
					maybeRestart()
				end)
			elseif settings["type"] == "select" then
				vim.ui.select(settings["options"], {
					prompt = "Update " .. name .. " to what>",
					telescope = require("telescope.themes").get_cursor(),
				}, function(value)
					if sessionOptions[name] == value then
						return
					end
					sessionOptions[name] = value
					maybeRestart()
				end)
			else
				return
			end
		end
	)
end

M.setup()

return M
