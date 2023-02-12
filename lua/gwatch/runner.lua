local Runner = { pid = nil }
local options = require("gwatch.config").options

local ll = vim.log.levels
local notify = function(msg, level)
	if level == nil then
		level = ll.INFO
	end
	vim.notify(msg, level)
end

local inspect = function(t)
	notify(vim.inspect(t))
end

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
			notify("Failed to stop " .. Runner.pid, ll.ERROR)
		end

		Runner.pid = nil
	end
end

function Runner.Watch(opts)
	Runner.Stop()
	local ftype = vim.bo.filetype
	local ftypeOpts = {}
	if options and options.lang and options.lang[ftype] then
		ftypeOpts = options.lang[ftype] or {}
	end
	opts = vim.tbl_deep_extend("force", {}, getopts(), options.default, ftypeOpts, opts or {})
	inspect(opts)
	local path = opts.path or vim.fn.getcwd()

	local cb = opts.callback and type(opts.callback) == "function" and opts.callback or inspect
	opts.on_stdout = function(_, data, _)
		for _, value in ipairs(data) do
			if string.len(value) > 0 then
				cb(value)
			end
		end
	end

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

	Runner.pid = vim.fn.jobstart(command, opts)
	cb("gwatching\n" .. vim.inspect(command) .. "\nWith options\n" .. vim.inspect(opts))
end

return Runner
