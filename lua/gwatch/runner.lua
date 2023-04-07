local Runner = { pid = nil }

local function getopts()
	local ui = require("gwatch.ui")

	function OnInput(input, term, bufnr, data)
		vim.api.nvim_chan_send(Runner.pid, data)
	end

	ui.SetOnStdin(OnInput)
	ui.term_open()
	local opts = ui.dimensions()
	opts.cwd = vim.fn.getcwd()
	-- connect both stdout and stderr to a pseudo-terminal which is passed to the on_stdout callback
	-- When using this flag, we get colors for free in the terminal view
	opts.pty = true
	return opts
end

function Runner.Stop()
	-- Stop any running gwatch instance
	if Runner.pid then
		local success = vim.fn.jobstop(Runner.pid) == 1
		if not success then
			vim.notify("Failed to stop " .. Runner.pid, vim.log.levels.ERROR)
		end

		Runner.pid = nil
	end
end

local function stringJoin(strings, sep)
	local len = #strings
	if len == 0 then
		return ""
	end
	local str = strings[1]
	for i = 2, len do
		local s = strings[i]
		str = str .. sep .. s
	end
	return str
end

function Runner.Watch(opts)
	local cfg = require("gwatch.config")
	local options = cfg.options()
	local project_overrides = cfg.project_overrides()

	Runner.Stop()
	local ftype = vim.bo.filetype
	local ftypeOpts = {}
	if options and options.lang and options.lang[ftype] then
		ftypeOpts = options.lang[ftype] or {}
	end

	if project_overrides and project_overrides.lang and project_overrides.lang[ftype] then
		ftypeOpts = vim.tbl_deep_extend("force", ftypeOpts, project_overrides.lang[ftype])
	end

	opts = vim.tbl_deep_extend(
		"force",
		{},
		getopts(),
		options.default,
		opts or {},
		project_overrides,
		ftypeOpts,
		cfg.overrides() or {}
	)
	local cb = opts.callback and type(opts.callback) == "function" and opts.callback or function(_) end

	opts.on_stdout = function(_, data, _)
		local s = stringJoin(data, "\r\n")
		if string.len(s) > 0 then
			cb(s)
		end
	end
	opts.on_stderr = opts.on_stdout
	opts.on_exit = function()
		Runner.pid = nil
		require("gwatch.ui").close_all()
	end

	local arguments = {}
	if opts.eventMask then
		arguments["eventMask"] = opts.eventMask
	end
	if opts.mode then
		arguments["mode"] = opts.mode
	end
	if opts.command then
		arguments["command"] = opts.command
	end

	local patterns = { "." }
	if type(opts.patterns) == "string" then
		table.insert(patterns, opts.patterns)
	elseif type(opts.patterns) == "table" then
		for _, pattern in ipairs(opts.patterns) do
			table.insert(patterns, pattern)
		end
	end

	local inspect = function(table)
		return vim.inspect(table, { newline = "\r\n" })
	end

	cb(
		"gwatching "
			.. inspect(patterns)
			.. "\r\nWith arguments "
			.. inspect(arguments)
			.. " in "
			.. inspect(opts.cwd)
			.. "\n\n\r"
	)

	local cmd = { options.gwatchPath }
	for k, v in pairs(arguments) do
		cmd[#cmd + 1] = "-" .. k
		cmd[#cmd + 1] = v
	end
	for _, v in ipairs(patterns) do
		cmd[#cmd + 1] = v
	end
	local ok = true
	ok, Runner.pid = pcall(vim.fn.jobstart, cmd, opts)
	if ok == false then
		Runner.pid = nil
		vim.notify("Failed to start command " .. vim.inspect(cmd), vim.log.levels.ERROR)
		cb("Failed to start " .. inspect(cmd) .. "\r\n")
		cb("Failed to start " .. inspect(options) .. "\r\n")
	end
end

-- local pid =require("gwatch.runner").pid

return Runner
