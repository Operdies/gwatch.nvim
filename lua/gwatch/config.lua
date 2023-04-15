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

function M.update_session_options(options)
	sessionOptions = vim.tbl_deep_extend("force", {}, sessionOptions, options or {})
	return M.options()
end

function M.options()
	local ftype = vim.bo.filetype

	-- merge the language specific options with the fallback optionsof a given table
	local with_lang = function(table)
		table = table or {}
		if table.lang and table.lang[ftype] then
			table = vim.tbl_deep_extend("force", {}, table, table.lang[ftype])
			table.lang = nil
		end
		return table
	end

	local cfg = with_lang(configOptions)
	local project_overrides = with_lang(M.project_overrides())
	local session = with_lang(sessionOptions)

	return vim.tbl_deep_extend("force", {}, defaultSettings, defaultSettings.default, cfg, project_overrides, session)
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
	trigger = { type = "select", options = { "hotkey", "watch" } },
	["window position"] = { type = "select", options = { "left", "right", "top", "bottom" } },
	profile = {
		type = "select",
		setter = function(name)
			local project_settings = M.project_overrides()
			if project_settings and project_settings.profiles and project_settings.profiles[name] then
				local profile = project_settings.profiles[name]
				-- Unset lang overrides and environment. Otherwise we might unintentionally keep unwanted settings around when swiching profiles
				sessionOptions.lang = nil
				sessionOptions.environment = nil
				M.update_session_options(profile)
			end
		end,
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
			local function call_setter(value)
				sessionOptions[name] = value
				if settings.setter and type(settings.setter) == "function" then
					settings.setter(value)
				end
			end
			if settings["type"] == "input" then
				settings.prompt = "Update " .. name .. " to what?"
				vim.ui.input(settings, function(value)
					if value == "" then
						value = nil
					end
					call_setter(value)
					maybeRestart()
				end)
			elseif settings["type"] == "select" then
				vim.ui.select(get_opts(settings), {
					prompt = "Update " .. name .. " to what?",
					telescope = require("telescope.themes").get_cursor(),
				}, function(value)
					call_setter(value)
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
