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
	return vim.tbl_deep_extend(
		"force",
		{},
		defaultSettings,
		configOptions or {},
		sessionOptions or {},
		M.project_overrides() or {},
		M.profile() or {}
	)
end

function M.overrides()
	return sessionOptions
end

function M.profile()
	local project_settings = M.project_overrides()
	if project_settings and project_settings.profiles then
		if sessionOptions.profile then
			return project_settings.profiles[sessionOptions.profile]
		end
	end
end

function M.project_overrides()
	local project_overrides = {}
	-- get the current project directory
	local project_dir = vim.fn.getcwd()
	-- check if the current directory has a gwatch.cfg file
	if vim.fn.filereadable(project_dir .. "/gwatch.json") == 1 then
		-- if it does, then read it and use it as the config file
		local content = vim.fn.readfile(project_dir .. "/gwatch.json")
		-- overrides = vim.fn.json_decode(vim.fn.readfile(project_dir .. "/gwatch.cfg"))
		local success
		success, project_overrides = pcall(vim.fn.json_decode, content)
		if not success then
			vim.notify("Failed to parse gwatch.json file", vim.log.levels.ERROR)
			project_overrides = {}
		end
	end
	return project_overrides
end

local settingsTree = {
	command = { type = "input", default = nil },
	["window width"] = { type = "input", default = "80" },
	["window height"] = { type = "input", default = "20" },
	mode = { type = "select", options = { "block", "kill", "concurrent" } },
	["window position"] = { type = "select", options = { "left", "right", "top", "bottom" } },
	profile = {
		type = "select",
		options = function()
			local overrides = M.project_overrides()
			if overrides and overrides.profiles then
				return vim.tbl_keys(overrides.profiles)
			end
		end,
	},
}

local function maybeRestart()
	require("gwatch").maybeRestart()
end

M.settings = function()
	local get_opts = function(tab)
		if tab and tab.options and type(tab.options) == "function" then
			return tab.options() or {}
		end
		return tab.options
	end

	local keyset = {}
	for k, v in pairs(settingsTree) do
		local opts = get_opts(v)
		-- filter out settings with 0 options
		if opts == nil or #opts > 0 then
			keyset[#keyset + 1] = k
		end
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
				settings.prompt = "Update " .. name .. " to what?"
				vim.ui.input(settings, function(value)
					if value == "" then
						value = nil
					end
					sessionOptions[name] = value
					maybeRestart()
				end)
			elseif settings["type"] == "select" then
				vim.ui.select(get_opts(settings), {
					prompt = "Update " .. name .. " to what?",
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
