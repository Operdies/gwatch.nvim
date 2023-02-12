local Runner = { pid = nil }

local function getopts()
	local opts = {}
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

function Runner.Watch(opts)
	local options = require("gwatch.config").options

	Runner.Stop()
	local ftype = vim.bo.filetype
	local ftypeOpts = {}
	if options and options.lang and options.lang[ftype] then
		ftypeOpts = options.lang[ftype] or {}
	end
	opts = vim.tbl_deep_extend("force", {}, getopts(), options.default, ftypeOpts, opts or {})

	local cb = opts.callback and type(opts.callback) == "function" and opts.callback or nil
	if cb ~= nil then
		opts.on_stdout = function(_, data, _)
			local s = ""
			for _, value in ipairs(data) do
				s = s .. value .. "\r\n"
			end

			if string.len(s) > 0 then
				cb(s)
			end
		end
		opts.on_stderr = opts.on_stdout
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

	local patterns = { opts.path or vim.fn.getcwd() }
	if type(opts.patterns) == "string" then
		table.insert(patterns, opts.patterns)
	elseif type(opts.patterns) == "table" then
		for _, pattern in ipairs(opts.patterns) do
			table.insert(patterns, pattern)
		end
	end

	local inspect = function(table)
		return "\r\n" .. vim.inspect(table, { newline = "\r\n" }) .. "\r\n"
	end

	if cb ~= nil then
		cb("gwatching" .. inspect(patterns) .. "With arguments" .. inspect(arguments))
	end

	local cmd = { options.gwatchPath }
	for k, v in pairs(arguments) do
		cmd[#cmd + 1] = "-" .. k
		cmd[#cmd + 1] = v
	end
	for _, v in ipairs(patterns) do
		cmd[#cmd + 1] = v
	end
	Runner.pid = vim.fn.jobstart(cmd, opts)
end

return Runner
