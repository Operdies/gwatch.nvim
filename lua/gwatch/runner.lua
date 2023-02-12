local Runner = { pid = nil }

local function getopts()
	local opts = {}
	opts.cwd = vim.fn.getcwd()
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
	local path = opts.path or vim.fn.getcwd()

	local cb = opts.callback and type(opts.callback) == "function" and opts.callback or nil
	opts.on_stdout = function(_, data, _)
		if cb == nil then
			return
		end
		local s = ""
		for _, value in ipairs(data) do
			s = s .. value .. "\n"
		end
		if string.len(s) > 0 then
			cb(s)
		end
	end
	opts.on_stderr = opts.on_stdout

	local command = { options.gwatchPath }
	if opts.eventMask then
		command[#command + 1] = "-eventMask"
		command[#command + 1] = opts.eventMask
	end
	if opts.mode then
		command[#command + 1] = "-mode"
		command[#command + 1] = opts.mode
	end
	if opts.command then
		command[#command + 1] = "-command"
		command[#command + 1] = opts.command
	end
	command[#command + 1] = path

	if type(opts.patterns) == "string" then
		command[#command + 1] = opts.patterns
	elseif type(opts.patterns) == "table" then
		for _, pattern in ipairs(opts.patterns) do
			command[#command + 1] = pattern
		end
	end

	Runner.pid = vim.fn.jobstart(command, opts)
	if cb ~= nil then
		cb("gwatching\n" .. vim.inspect(command) .. "\nWith options\n" .. vim.inspect(opts))
	end
end

return Runner
