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

local function touchFile(name)
	if name ~= nil then
		local f = io.open(name, "w")
		if f ~= nil then
			f:close()
		end
	end
end

-- Trigger a gwatch event manually
function Runner.Trigger()
	touchFile(Runner.hotkeyFile)
end

function Runner.Watch()
	local cfg = require("gwatch.config")

	local opts = cfg.options()
	local term_opts = getopts()
	term_opts.env = opts.environment

	Runner.Stop()

	local action = opts.callback and type(opts.callback) == "function" and opts.callback or function(_) end

	term_opts.on_stdout = function(_, data, _)
		local s = stringJoin(data, "\r\n")
		if string.len(s) > 0 then
			action(s)
		end
	end
	term_opts.on_stderr = term_opts.on_stdout

	local arguments = {}
	if opts.mode then
		arguments["mode"] = opts.mode
	end
	if opts.command then
		arguments["command"] = opts.command
	end

	-- always watch a temp file so we can manually trigger events
	Runner.hotkeyFile = vim.fn.tempname()

	-- Run Trigger() to create the file
	Runner.Trigger()
	local patterns = { Runner.hotkeyFile }

	if opts.trigger == "hotkey" then
		-- override the event mask to only watch for WRITE|CHMOD
    -- On mac, touching seems to cause a chmod event, while it causes a write event on linux
		opts.eventMask = "WRITE|CHMOD"
	else
		table.insert(patterns, ".")
		if type(opts.patterns) == "string" then
			table.insert(patterns, opts.patterns)
		elseif type(opts.patterns) == "table" then
			for _, pattern in ipairs(opts.patterns) do
				table.insert(patterns, pattern)
			end
		end
	end

	if opts.eventMask then
		if type(opts.eventMask) == "string" then
			arguments["eventMask"] = opts.eventMask
		elseif type(opts.eventMask) == "table" then
			arguments["eventMask"] = stringJoin(opts.eventMask, "|")
		end
	end

	local inspect = function(table)
		return vim.inspect(table, { newline = "\r\n" })
	end

	local cmd = { opts.gwatchPath }
	for k, v in pairs(arguments) do
		cmd[#cmd + 1] = "-" .. k
		cmd[#cmd + 1] = v
	end

	for _, v in ipairs(patterns) do
		cmd[#cmd + 1] = v
	end

	action(
		"gwatching "
			.. inspect(patterns)
			.. "\r\nWith arguments "
			.. inspect(arguments) -- .. " with options "
			-- .. inspect(opts)
			-- .. " with terminal options "
			-- .. inspect(term_opts)
			.. "\n\n\r"
	)

	local ok = true
	ok, Runner.pid = pcall(vim.fn.jobstart, cmd, term_opts)
	if ok == false then
		Runner.pid = nil
		vim.notify("Failed to start command " .. vim.inspect(cmd), vim.log.levels.ERROR)
		action("Failed to start " .. inspect(cmd) .. "\r\n")
		action("Failed to start " .. inspect(opts) .. "\r\n")
	end
end

-- local pid =require("gwatch.runner").pid

return Runner
